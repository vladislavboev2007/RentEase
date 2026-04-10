import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import List, Optional
import uuid
from datetime import datetime
import asyncio

# Настройки для Yandex Mail
SMTP_SERVER = "smtp.yandex.ru"
SMTP_PORT = 587  # Для TLS
SMTP_PORT_SSL = 465  # Для SSL

# Данные для авторизации (замените на свои)
SMTP_USER = "boeff.vladislav2017@yandex.ru"  # Ваш email на Яндексе
SMTP_PASSWORD = "pqmzqqziaocazoaa"  # Пароль приложения (не от аккаунта!)

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class YandexMailSender:
    """Класс для отправки писем через Yandex Mail"""

    def __init__(self, username: str = None, password: str = None):
        """
        Инициализация отправителя писем

        :param username: Email на Яндексе
        :param password: Пароль приложения
        """
        self.username = username or SMTP_USER
        self.password = password or SMTP_PASSWORD
        self.server = None

    def connect(self) -> bool:
        """Установка соединения с SMTP сервером"""
        try:
            self.server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
            self.server.starttls()  # Включаем TLS
            self.server.login(self.username, self.password)
            logger.info(f"✅ Успешное подключение к {SMTP_SERVER}")
            return True
        except Exception as e:
            logger.error(f"❌ Ошибка подключения к SMTP: {e}")
            return False

    def disconnect(self):
        """Закрытие соединения"""
        if self.server:
            try:
                self.server.quit()
                logger.info("✅ Соединение закрыто")
            except:
                pass

    def send_email(self,
                   to_email: str,
                   subject: str,
                   html_content: str = None,
                   text_content: str = None,
                   from_name: str = "RentEase") -> bool:
        """
        Отправка одного письма с улучшенной защитой от спама
        """
        import re
        from email.utils import formataddr
        import time

        try:
            # Создаем сообщение
            msg = MIMEMultipart('alternative')

            # Форматируем отправителя
            sender_email = self.username
            msg['From'] = formataddr((from_name, sender_email))
            msg['To'] = to_email
            msg['Subject'] = subject
            msg['Date'] = datetime.now().strftime('%a, %d %b %Y %H:%M:%S %z')

            # Добавляем заголовки для предотвращения спама
            msg['X-Mailer'] = 'RentEase/1.0'
            msg['X-Priority'] = '3'
            msg['Message-ID'] = f"<{uuid.uuid4().hex}@rentease.ru>"

            # Добавляем текстовую версию (обязательно)
            if text_content:
                msg.attach(MIMEText(text_content, 'plain', 'utf-8'))
            elif html_content:
                # Очищаем HTML для текстовой версии
                plain_text = re.sub(r'<[^>]+>', ' ', html_content)
                plain_text = re.sub(r'\s+', ' ', plain_text)
                msg.attach(MIMEText(plain_text, 'plain', 'utf-8'))

            # Добавляем HTML-версию
            if html_content:
                msg.attach(MIMEText(html_content, 'html', 'utf-8'))

            # Подключаемся и отправляем
            if not self.server:
                if not self.connect():
                    return False

            # Добавляем небольшую задержку для имитации человеческой отправки
            time.sleep(0.5)

            self.server.send_message(msg)
            logger.info(f"✅ Письмо отправлено на {to_email}")
            return True

        except Exception as e:
            logger.error(f"❌ Ошибка отправки письма: {e}")
            return False

    def send_bulk(self,
                  recipients: List[str],
                  subject: str,
                  html_content: str = None,
                  text_content: str = None,
                  from_name: str = "RentEase") -> dict:
        """
        Массовая рассылка писем

        :param recipients: Список email-ов получателей
        :param subject: Тема письма
        :param html_content: HTML-содержимое
        :param text_content: Текстовое содержимое
        :param from_name: Имя отправителя
        :return: Словарь с результатами {email: True/False}
        """
        results = {}

        # Подключаемся один раз для всех писем
        if not self.connect():
            return {email: False for email in recipients}

        try:
            for email in recipients:
                success = self.send_email(email, subject, html_content, text_content, from_name)
                results[email] = success
        finally:
            self.disconnect()

        return results

    def send_code(self, to_email: str, code: str, purpose: str = "registration") -> bool:
        """
        Отправка кода подтверждения

        :param to_email: Email получателя
        :param code: Код подтверждения
        :param purpose: Цель (registration/recovery)
        :return: True если успешно
        """
        purposes = {
            "registration": {
                "subject": "Код подтверждения регистрации в RentEase",
                "title": "Регистрация в RentEase"
            },
            "recovery": {
                "subject": "Восстановление пароля в RentEase",
                "title": "Восстановление доступа"
            }
        }

        purpose_data = purposes.get(purpose, purposes["registration"])

        # Создаем HTML-содержимое
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{
                    font-family: 'Segoe UI', Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }}
                .header {{
                    background: linear-gradient(135deg, #007bff 0%, #0056b3 100%);
                    color: white;
                    padding: 20px;
                    text-align: center;
                    border-radius: 10px 10px 0 0;
                }}
                .content {{
                    background: #f8f9fa;
                    padding: 30px;
                    border: 1px solid #e9ecef;
                    border-radius: 0 0 10px 10px;
                }}
                .code {{
                    font-size: 32px;
                    font-weight: 700;
                    color: #007bff;
                    text-align: center;
                    padding: 20px;
                    background: white;
                    border-radius: 10px;
                    margin: 20px 0;
                    letter-spacing: 5px;
                }}
                .footer {{
                    margin-top: 20px;
                    font-size: 12px;
                    color: #6c757d;
                    text-align: center;
                }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>RentEase</h1>
            </div>
            <div class="content">
                <h2>{purpose_data['title']}</h2>
                <p>Здравствуйте!</p>
                <p>Для завершения {purpose_data['title'].lower()} используйте следующий код подтверждения:</p>

                <div class="code">{code[:4]}-{code[4:]}</div>

                <p>Код действителен в течение 5 минут.</p>
                <p>Если вы не запрашивали этот код, просто проигнорируйте данное письмо.</p>

                <div class="footer">
                    <p>© 2024 RentEase. Все права защищены.</p>
                    <p>Это автоматическое письмо, пожалуйста, не отвечайте на него.</p>
                </div>
            </div>
        </body>
        </html>
        """

        text_content = f"""
        RentEase - {purpose_data['title']}

        Здравствуйте!

        Для завершения {purpose_data['title'].lower()} используйте следующий код подтверждения:

        {code[:4]}-{code[4:]}

        Код действителен в течение 5 минут.

        Если вы не запрашивали этот код, просто проигнорируйте данное письмо.

        © 2024 RentEase
        """

        return self.send_email(to_email, purpose_data['subject'], html_content, text_content)


# Функции для быстрого использования
def send_recovery_code(email: str, code: str) -> bool:
    """Отправка кода восстановления"""
    sender = YandexMailSender()
    return sender.send_code(email, code, "recovery")


def send_registration_code(email: str, code: str) -> bool:
    """Отправка кода регистрации"""
    sender = YandexMailSender()
    return sender.send_code(email, code, "registration")


def send_block_notification(email: str, full_name: str, is_blocked: bool, reason: str = None, duration: str = None,
                            comment: str = None) -> bool:
    """
    Отправка уведомления о блокировке/разблокировке пользователя
    """
    from email.utils import formataddr
    import uuid
    import re

    sender = YandexMailSender()

    # Карта причин на русском
    reasons_map = {
        "fraud": "Мошеннические действия (попытка получения предоплаты, фишинг)",
        "spam": "Массовая рассылка спама",
        "fake_property": "Размещение фальшивых объектов недвижимости",
        "harassment": "Оскорбления и домогательства в чатах",
        "documents": "Предоставление поддельных документов",
        "multiple_accounts": "Создание нескольких аккаунтов для обхода ограничений",
        "other": "Другое нарушение правил платформы"
    }

    # Карта сроков на русском
    duration_map = {
        "7": "7 дней",
        "30": "30 дней",
        "permanent": "Навсегда (без возможности восстановления)"
    }

    if is_blocked:
        subject = "Уведомление о блокировке аккаунта в RentEase"

        # Получаем текст причины
        reason_text = reasons_map.get(reason, reason or "Нарушение правил платформы")
        duration_text = duration_map.get(duration, duration or "Временно")

        # Формируем HTML-письмо с подробностями
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #dc3545 0%, #b02a37 100%); color: white; padding: 20px; text-align: center; border-radius: 12px 12px 0 0; }}
                .content {{ background: #f8f9fa; padding: 25px; border: 1px solid #e9ecef; border-radius: 0 0 12px 12px; }}
                .reason-box {{ background: white; padding: 15px; border-left: 4px solid #dc3545; margin: 15px 0; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }}
                .comment-box {{ background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 15px 0; border-radius: 8px; }}
                .footer {{ margin-top: 20px; font-size: 12px; color: #6c757d; text-align: center; border-top: 1px solid #e9ecef; padding-top: 15px; }}
                .button {{ display: inline-block; background: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; margin-top: 15px; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h2 style="margin:0;">RentEase</h2>
                <p style="margin:5px 0 0; opacity:0.9;">Уведомление о блокировке аккаунта</p>
            </div>
            <div class="content">
                <p>Здравствуйте, <strong>{full_name}</strong>.</p>
                <p>Ваш аккаунт на платформе RentEase был <strong style="color:#dc3545;">заблокирован</strong>.</p>

                <div class="reason-box">
                    <strong>📋 Причина блокировки:</strong><br>
                    {reason_text}
                </div>

                <div class="reason-box">
                    <strong>⏱️ Срок блокировки:</strong><br>
                    {duration_text}
                </div>

                {f'''
                <div class="comment-box">
                    <strong>💬 Комментарий администратора:</strong><br>
                    {comment}
                </div>
                ''' if comment else ''}

                <p><strong>Что это значит?</strong></p>
                <ul>
                    <li>Вы не можете создавать новые объявления</li>
                    <li>Вы не можете отправлять сообщения другим пользователям</li>
                    <li>Ваши существующие объявления скрыты из поиска</li>
                    <li>Вы не можете подавать заявки на аренду</li>
                </ul>

                <p><strong>Как разблокировать аккаунт?</strong></p>
                <ul>
                    {f'<li>Если блокировка временная — дождитесь окончания срока ({duration_text})</li>' if duration != "permanent" else '<li>Блокировка является постоянной и не подлежит автоматической разблокировке</li>'}
                    <li>Если вы считаете блокировку ошибочной — обратитесь в службу поддержки: <strong>support@rentease.ru</strong></li>
                    <li>Приложите доказательства вашей правоты (скриншоты, документы)</li>
                </ul>

                <div style="text-align: center; margin-top: 20px;">
                    <a href="mailto:support@rentease.ru" class="button">Связаться с поддержкой</a>
                </div>
            </div>
            <div class="footer">
                <p>© 2024 RentEase. Все права защищены.</p>
                <p>Это автоматическое письмо, пожалуйста, не отвечайте на него.</p>
            </div>
        </body>
        </html>
        """

        text_content = f"""
RentEase - Уведомление о блокировке аккаунта

Здравствуйте, {full_name}.

Ваш аккаунт на платформе RentEase был заблокирован.

Причина блокировки: {reason_text}
Срок блокировки: {duration_text}
{f'Комментарий администратора: {comment}' if comment else ''}

Что это значит?
- Вы не можете создавать новые объявления
- Вы не можете отправлять сообщения другим пользователям
- Ваши существующие объявления скрыты из поиска
- Вы не можете подавать заявки на аренду

{f'Дождитесь окончания срока блокировки ({duration_text})' if duration != "permanent" else 'Блокировка является постоянной и не подлежит автоматической разблокировке'}

Если вы считаете блокировку ошибочной, напишите нам на support@rentease.ru.

С уважением,
Команда RentEase
        """

    else:
        subject = "Уведомление о разблокировке аккаунта в RentEase"

        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #28a745 0%, #1e7e34 100%); color: white; padding: 20px; text-align: center; border-radius: 12px 12px 0 0; }}
                .content {{ background: #f8f9fa; padding: 25px; border: 1px solid #e9ecef; border-radius: 0 0 12px 12px; }}
                .footer {{ margin-top: 20px; font-size: 12px; color: #6c757d; text-align: center; border-top: 1px solid #e9ecef; padding-top: 15px; }}
                .button {{ display: inline-block; background: #28a745; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; margin-top: 15px; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h2 style="margin:0;">RentEase</h2>
                <p style="margin:5px 0 0; opacity:0.9;">Уведомление о разблокировке аккаунта</p>
            </div>
            <div class="content">
                <p>Здравствуйте, <strong>{full_name}</strong>.</p>
                <p>Ваш аккаунт на платформе RentEase был <strong style="color:#28a745;">разблокирован</strong>.</p>

                <p>Вы снова можете пользоваться всеми функциями сервиса:</p>
                <ul>
                    <li>✅ Размещать объекты недвижимости</li>
                    <li>✅ Отправлять сообщения другим пользователям</li>
                    <li>✅ Подавать заявки на аренду</li>
                    <li>✅ Заключать договоры</li>
                </ul>

                <p><strong>Пожалуйста, соблюдайте правила платформы!</strong></p>
                <p>При повторном нарушении аккаунт может быть заблокирован навсегда.</p>

                <div style="text-align: center; margin-top: 20px;">
                    <a href="https://rentease.ru" class="button">Перейти на сайт</a>
                </div>
            </div>
            <div class="footer">
                <p>© 2024 RentEase. Все права защищены.</p>
                <p>Это автоматическое письмо, пожалуйста, не отвечайте на него.</p>
            </div>
        </body>
        </html>
        """

        text_content = f"""
RentEase - Уведомление о разблокировке аккаунта

Здравствуйте, {full_name}.

Ваш аккаунт на платформе RentEase был разблокирован.

Вы снова можете пользоваться всеми функциями сервиса:
- Размещать объекты недвижимости
- Отправлять сообщения другим пользователям
- Подавать заявки на аренду
- Заключать договоры

Пожалуйста, соблюдайте правила платформы!

С уважением,
Команда RentEase
        """

    return sender.send_email(email, subject, html_content, text_content)


def send_agent_notification(email: str, full_name: str, is_agent: bool) -> bool:
    """Отправка уведомления о назначении/снятии роли агента"""
    sender = YandexMailSender()

    if is_agent:
        subject = "Вы стали агентом в RentEase"
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #007bff 0%, #0056b3 100%); color: white; padding: 20px; text-align: center; border-radius: 12px 12px 0 0; }}
                .content {{ background: #f8f9fa; padding: 25px; border: 1px solid #e9ecef; border-radius: 0 0 12px 12px; }}
                .footer {{ margin-top: 20px; font-size: 12px; color: #6c757d; text-align: center; }}
            </style>
        </head>
        <body>
            <div class="header"><h2>RentEase</h2></div>
            <div class="content">
                <p>Здравствуйте, <strong>{full_name}</strong>!</p>
                <p>Вам была назначена роль <strong>агента</strong> в системе RentEase.</p>
                <p>Теперь вам доступны дополнительные возможности:</p>
                <ul>
                    <li>📊 Статистика работы агента</li>
                    <li>📋 Управление объектами собственников</li>
                    <li>💬 Работа с заявками</li>
                    <li>📈 Аналитика эффективности</li>
                </ul>
                <p>Войдите в систему, чтобы начать работу.</p>
            </div>
            <div class="footer"><p>© 2024 RentEase. Все права защищены.</p></div>
        </body>
        </html>
        """
    else:
        subject = "Роль агента снята в RentEase"
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #6c757d 0%, #495057 100%); color: white; padding: 20px; text-align: center; border-radius: 12px 12px 0 0; }}
                .content {{ background: #f8f9fa; padding: 25px; border: 1px solid #e9ecef; border-radius: 0 0 12px 12px; }}
                .footer {{ margin-top: 20px; font-size: 12px; color: #6c757d; text-align: center; }}
            </style>
        </head>
        <body>
            <div class="header"><h2>RentEase</h2></div>
            <div class="content">
                <p>Здравствуйте, <strong>{full_name}</strong>!</p>
                <p>С вас была снята роль <strong>агента</strong> в системе RentEase.</p>
                <p>Если вы считаете это ошибкой, обратитесь в службу поддержки: <strong>support@rentease.ru</strong></p>
            </div>
            <div class="footer"><p>© 2024 RentEase. Все права защищены.</p></div>
        </body>
        </html>
        """

    text_content = f"RentEase - {subject}\n\nЗдравствуйте, {full_name}!\n\n{'Вам была назначена роль агента.' if is_agent else 'С вас была снята роль агента.'}\n\nС уважением, Команда RentEase"

    return sender.send_email(email, subject, html_content, text_content)


def send_application_status_notification(to_email: str, full_name: str, status: str, property_title: str,
                                         comment: str = None):
    subject = f"Заявка на {property_title} - {status}"
    if status == 'approved':
        html = f"<p>Здравствуйте, {full_name}!</p><p>Ваша заявка на объект «{property_title}» одобрена.</p>"
        if comment:
            html += f"<p>Комментарий: {comment}</p>"
        html += "<p>Договор будет сформирован автоматически.</p>"
    else:  # rejected
        html = f"<p>Здравствуйте, {full_name}!</p><p>Ваша заявка на объект «{property_title}» отклонена.</p>"
        if comment:
            html += f"<p>Причина: {comment}</p>"

    sender = YandexMailSender()
    sender.send_email(to_email, subject, html)


def send_contract_signed_notification(to_email: str, full_name: str, contract_number: str, property_title: str,
                                      is_owner: bool = False):
    """
    Отправка уведомления о подписании договора
    is_owner: True - для собственника, False - для арендатора
    """
    if is_owner:
        subject = f"Арендатор подписал договор {contract_number}"
        html = f"""
        <p>Здравствуйте, {full_name}!</p>
        <p>Арендатор подписал договор <strong>{contract_number}</strong> на объект «{property_title}».</p>
        <p>После вашей подписи договор вступит в силу.</p>
        <p><a href="https://rentease.ru/my/contracts">Перейти к договорам</a></p>
        """
    else:
        subject = f"Собственник подписал договор {contract_number}"
        html = f"""
        <p>Здравствуйте, {full_name}!</p>
        <p>Собственник подписал договор <strong>{contract_number}</strong> на объект «{property_title}».</p>
        <p>Договор вступил в силу.</p>
        <p><a href="https://rentease.ru/my/contracts">Перейти к договорам</a></p>
        """

    sender = YandexMailSender()
    sender.send_email(to_email, subject, html)


def send_contract_fully_signed_notification(to_email: str, full_name: str, contract_number: str, property_title: str):
    """
    Отправка уведомления о полном подписании договора (обеими сторонами)
    """
    subject = f"Договор {contract_number} полностью подписан"
    html = f"""
    <p>Здравствуйте, {full_name}!</p>
    <p>Договор <strong>{contract_number}</strong> на объект «{property_title}» полностью подписан обеими сторонами.</p>
    <p>Вы можете скачать договор и акт приёма-передачи в личном кабинете.</p>
    <p><a href="https://rentease.ru/my/contracts">Скачать документы</a></p>
    """

    sender = YandexMailSender()
    sender.send_email(to_email, subject, html)


def send_contract_cancelled_notification(to_email: str, full_name: str, contract_number: str, property_title: str):
    """
    Отправка уведомления об отмене договора
    """
    subject = f"Договор {contract_number} отменён"
    html = f"""
    <p>Здравствуйте, {full_name}!</p>
    <p>Договор <strong>{contract_number}</strong> на объект «{property_title}» был отменён.</p>
    <p>Если у вас есть вопросы, свяжитесь с поддержкой.</p>
    """

    sender = YandexMailSender()
    sender.send_email(to_email, subject, html)

# Пример использования
if __name__ == "__main__":
    # Тестирование
    import re

    # Замените на свои данные
    test_email = "vladislav.boev02@mail.ru"
    test_code = "12345678"

    # Отправка тестового письма
    sender = YandexMailSender()
    if sender.send_code(test_email, test_code, "registration"):
        print(f"✅ Тестовое письмо отправлено на {test_email}")
    else:
        print("❌ Ошибка отправки")