from openpyxl import Workbook
from openpyxl.chart import BarChart, Reference, PieChart
import os
import time
from datetime import datetime
from docx import Document
from docx.shared import Pt, Cm, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import ImageReader
from openpyxl import Workbook
from openpyxl.chart import BarChart, PieChart, Reference
import tempfile
from pathlib import Path
from PIL import Image
import io
import uuid
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
TEMP_DIR = BASE_DIR / "temp"
TEMP_DIR.mkdir(exist_ok=True)

def cleanup_temp_files(max_age_hours=1):
    """Удаляет временные файлы старше указанного количества часов"""
    now = time.time()
    for f in TEMP_DIR.glob("*"):
        if f.is_file():
            if now - f.stat().st_mtime > max_age_hours * 3600:
                f.unlink()


def register_cyrillic_fonts():
    """Регистрация шрифтов Arial для поддержки кириллицы"""
    fonts_registered = {}

    # Пути к шрифтам Arial в разных ОС
    possible_paths = [
        # Windows
        "C:\\Windows\\Fonts\\arial.ttf",
        "C:\\Windows\\Fonts\\Arial.ttf",
        "C:\\WINNT\\Fonts\\arial.ttf",
        # Linux (если установлены)
        "/usr/share/fonts/truetype/msttcorefonts/Arial.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        # MacOS
        "/Library/Fonts/Arial.ttf",
    ]

    # Поиск обычного шрифта
    regular_path = None
    for path in possible_paths:
        if os.path.exists(path):
            regular_path = path
            break

    # Поиск жирного шрифта
    bold_paths = [
        "C:\\Windows\\Fonts\\arialbd.ttf",
        "C:\\Windows\\Fonts\\Arialbd.ttf",
        "/usr/share/fonts/truetype/msttcorefonts/Arial_Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
    ]

    bold_path = None
    for path in bold_paths:
        if os.path.exists(path):
            bold_path = path
            break

    # Регистрируем шрифты, если найдены
    try:
        if regular_path and os.path.exists(regular_path):
            pdfmetrics.registerFont(TTFont('Arial', regular_path))
            fonts_registered['regular'] = True
            print(f"✅ Шрифт Arial зарегистрирован: {regular_path}")
        else:
            print("⚠️ Шрифт Arial не найден, используется стандартный")
            fonts_registered['regular'] = False

        if bold_path and os.path.exists(bold_path):
            pdfmetrics.registerFont(TTFont('Arial-Bold', bold_path))
            fonts_registered['bold'] = True
            print(f"✅ Шрифт Arial-Bold зарегистрирован: {bold_path}")
        else:
            print("⚠️ Шрифт Arial-Bold не найден")
            fonts_registered['bold'] = False

    except Exception as e:
        print(f"❌ Ошибка регистрации шрифтов: {e}")
        fonts_registered['regular'] = False
        fonts_registered['bold'] = False

    return fonts_registered


# Регистрируем шрифты при импорте
FONTS_LOADED = register_cyrillic_fonts()

def generate_contract_docx(contract_data: dict, property_data: dict, tenant_data: dict, owner_data: dict, output_path: str = None):
    """
    Генерирует договор аренды в формате Word.
    В конце документа добавляет место для подписи с картинкой, если сторона подписала.
    """
    doc = Document()

    # Настройка полей
    sections = doc.sections
    for section in sections:
        section.top_margin = Cm(2)
        section.bottom_margin = Cm(2)
        section.left_margin = Cm(2.5)
        section.right_margin = Cm(1.5)

    style = doc.styles['Normal']
    style.font.name = 'Times New Roman'
    style.font.size = Pt(14)

    # Заголовок
    title = doc.add_heading('ДОГОВОР АРЕНДЫ', level=1)
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.runs[0].font.size = Pt(18)
    title.runs[0].font.bold = True

    subtitle = doc.add_heading(f'недвижимого имущества № {contract_data.get("number", "___")}', level=2)
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    subtitle.runs[0].font.size = Pt(16)
    subtitle.runs[0].font.bold = True

    doc.add_paragraph()

    # Город и дата
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p.add_run(f'г. {property_data.get("city", "Москва")}     «{contract_data.get("day", "___")}» {contract_data.get("month", "_____")} {contract_data.get("year", "___")} г.').font.size = Pt(14)

    doc.add_paragraph()

    # Преамбула
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.line_spacing = 1.5
    p.paragraph_format.first_line_indent = Cm(1.25)
    p.add_run(
        f'{owner_data.get("name", "_______________")}, именуем__ в дальнейшем «Арендодатель», '
        f'в лице {owner_data.get("rep", "_______________")}, действующ__ на основании '
        f'{owner_data.get("basis", "_______________")}, с одной стороны, и '
        f'{tenant_data.get("name", "_______________")}, именуем__ в дальнейшем «Арендатор», '
        f'в лице {tenant_data.get("rep", "_______________")}, действующ__ на основании '
        f'{tenant_data.get("basis", "_______________")}, с другой стороны, '
        f'заключили настоящий Договор о нижеследующем:'
    ).font.size = Pt(14)

    doc.add_paragraph()

    # Раздел 1. Предмет договора
    heading1 = doc.add_heading('1. ПРЕДМЕТ ДОГОВОРА', level=2)
    heading1.runs[0].font.size = Pt(14)
    heading1.runs[0].font.bold = True

    property_type = {
        'apartment': 'квартиру',
        'house': 'дом',
        'commercial': 'нежилое помещение'
    }.get(property_data.get("type"), 'квартиру')

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'1.1. Арендодатель обязуется передать Арендатору во временное владение и пользование '
        f'{property_type}, расположенную по адресу: {property_data.get("address", "_______________")}, '
        f'г. {property_data.get("city", "_______________")} (далее – «Помещение»), для использования в целях, '
        f'указанных в п. 1.2 настоящего Договора.'
    ).font.size = Pt(14)

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'1.2. Помещение предоставляется для использования под {contract_data.get("purpose", "проживание")}.'
    ).font.size = Pt(14)

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'1.3. Характеристики Помещения:\n'
        f'   - общая площадь: {property_data.get("area", "___")} кв. м;\n'
        f'   - количество комнат: {property_data.get("rooms", "___")}.'
    ).font.size = Pt(14)

    doc.add_paragraph()

    # Раздел 2. Срок аренды
    heading2 = doc.add_heading('2. СРОК АРЕНДЫ', level=2)
    heading2.runs[0].font.size = Pt(14)
    heading2.runs[0].font.bold = True

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'2.1. Настоящий Договор заключен сроком на {contract_data.get("duration_months", "___")} месяцев '
        f'и действует с «{contract_data.get("start_day", "___")}» {contract_data.get("start_month", "_____")} '
        f'{contract_data.get("start_year", "___")} г. по «{contract_data.get("end_day", "___")}» '
        f'{contract_data.get("end_month", "_____")} {contract_data.get("end_year", "___")} г.'
    ).font.size = Pt(14)

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'2.2. Если ни одна из Сторон не заявит о своем намерении прекратить Договор не позднее чем за 30 '
        f'(тридцать) дней до окончания срока его действия, Договор считается продленным на тот же срок '
        f'на тех же условиях.'
    ).font.size = Pt(14)

    doc.add_paragraph()

    # Раздел 3. Арендная плата
    heading3 = doc.add_heading('3. АРЕНДНАЯ ПЛАТА И РАСЧЕТЫ', level=2)
    heading3.runs[0].font.size = Pt(14)
    heading3.runs[0].font.bold = True

    interval_text = {
        'month': 'ежемесячно',
        'week': 'еженедельно'
    }.get(property_data.get("interval"), 'ежемесячно')

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'3.1. Арендная плата за Помещение устанавливается в размере '
        f'{contract_data.get("monthly_price", "___")} рублей и вносится {interval_text}.'
    ).font.size = Pt(14)

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'3.2. Арендная плата вносится путем перечисления денежных средств на расчетный счет Арендодателя '
        f'или наличными денежными средствами не позднее {contract_data.get("payment_day", "10")} числа каждого месяца.'
    ).font.size = Pt(14)

    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    p.paragraph_format.line_spacing = 1.5
    p.add_run(
        f'3.3. Сумма обеспечительного платежа (депозита) составляет '
        f'{contract_data.get("deposit", "___")} рублей и вносится Арендатором до подписания настоящего Договора. '
        f'Указанная сумма возвращается Арендатору при расторжении Договора при отсутствии задолженности и повреждений имущества.'
    ).font.size = Pt(14)

    doc.add_paragraph()

    # Подписи сторон
    doc.add_heading('ПОДПИСИ СТОРОН', level=2).alignment = WD_ALIGN_PARAGRAPH.CENTER

    # Таблица для подписей
    table = doc.add_table(rows=4, cols=2)
    table.autofit = False
    table.columns[0].width = Cm(8)
    table.columns[1].width = Cm(8)

    # Арендодатель
    table.cell(0, 0).text = 'АРЕНДОДАТЕЛЬ:'
    table.cell(1, 0).text = owner_data.get("name", "___________")
    table.cell(2, 0).text = f'Паспорт: {owner_data.get("passport", "___________")}'

    # Если собственник подписал, вставляем картинку подписи
    if contract_data.get("owner_signed"):
        # Добавляем изображение подписи
        run = table.cell(3, 0).paragraphs[0].add_run()
        signature_path = BASE_DIR / "resources" / "signature.png"
        if signature_path.exists():
            run.add_picture(str(signature_path), width=Cm(3), height=Cm(1.5))
        else:
            table.cell(3, 0).text = '(Подписано)'
    else:
        table.cell(3, 0).text = '_______________'

    # Арендатор
    table.cell(0, 1).text = 'АРЕНДАТОР:'
    table.cell(1, 1).text = tenant_data.get("name", "___________")
    table.cell(2, 1).text = f'Паспорт: {tenant_data.get("passport", "___________")}'

    if contract_data.get("tenant_signed"):
        run = table.cell(3, 1).paragraphs[0].add_run()
        signature_path = BASE_DIR / "resources" / "signature.png"
        if signature_path.exists():
            run.add_picture(str(signature_path), width=Cm(3), height=Cm(1.5))
        else:
            table.cell(3, 1).text = '(Подписано)'
    else:
        table.cell(3, 1).text = '_______________'

    # Сохраняем файл
    if output_path:
        doc.save(output_path)
        return output_path
    else:
        temp_dir = BASE_DIR / "temp"
        temp_dir.mkdir(exist_ok=True)
        filename = f"contract_{uuid.uuid4().hex}.docx"
        filepath = temp_dir / filename
        doc.save(str(filepath))
        return str(filepath)


def generate_act_pdf(contract_data: dict, property_data: dict, tenant_data: dict, owner_data: dict,
                     output_path: str = None):
    """
    Генерирует акт приема-передачи в формате PDF с поддержкой кириллицы.
    """
    if output_path is None:
        filename = f"act_{uuid.uuid4().hex}.pdf"
        output_path = str(TEMP_DIR / filename)

    c = canvas.Canvas(output_path, pagesize=A4)
    width, height = A4

    # Определяем, какие шрифты использовать
    if FONTS_LOADED.get('regular') and FONTS_LOADED.get('bold'):
        regular_font = 'Arial'
        bold_font = 'Arial-Bold'
        print("✅ Используется Arial с поддержкой кириллицы")
    else:
        # Запасной вариант - встроенный шрифт (кириллица НЕ поддерживается)
        regular_font = 'Helvetica'
        bold_font = 'Helvetica-Bold'
        print("⚠️ Шрифты не найдены, используется Helvetica (кириллица НЕ будет отображаться)")

    # Заголовок
    c.setFont(bold_font, 16)
    c.drawCentredString(width / 2, height - 40, "АКТ")
    c.setFont(bold_font, 14)
    c.drawCentredString(width / 2, height - 60, "приема-передачи нежилого помещения")

    # Адрес
    c.setFont(bold_font, 12)
    c.drawCentredString(width / 2, height - 90, "находящегося по адресу:")
    c.setFont(bold_font, 14)

    address = property_data.get("address", "_______________")
    if len(address) > 50:
        address = address[:50] + "..."
    c.drawCentredString(width / 2, height - 110, address)

    # Город и дата
    c.setFont(regular_font, 12)
    date_text = f'г. {property_data.get("city", "Москва")}     «{contract_data.get("day", "___")}» {contract_data.get("month", "_____")} {contract_data.get("year", "___")} г.'
    c.drawString(50, height - 140, date_text)

    # Основной текст
    y = height - 180
    lines = [
        f'{owner_data.get("name", "_______________")}, именуем__ в дальнейшем «Арендодатель», в лице',
        f'{owner_data.get("rep", "_______________")}, действующего на основании {owner_data.get("basis", "_______________")}, передал, а',
        f'{tenant_data.get("name", "_______________")}, именуем__ в дальнейшем «Арендатор», в лице',
        f'{tenant_data.get("rep", "_______________")}, действующ__ на основании {tenant_data.get("basis", "_______________")}, принял в аренду',
        f'нежилое помещение, расположенное по адресу {property_data.get("address", "_______________")} общей площадью',
        f'{property_data.get("area", "___")} кв. м для использования под {contract_data.get("purpose", "проживание")} согласно договору N',
        f'{contract_data.get("number", "___")} аренды нежилого помещения от',
        f'«{contract_data.get("start_day", "___")}» {contract_data.get("start_month", "_____")} {contract_data.get("start_year", "___")} г.'
    ]

    for line in lines:
        c.setFont(regular_font, 12)
        c.drawString(50, y, line)
        y -= 20

    # Состояние помещения
    y -= 20
    state_text = ('Техническое состояние нежилого помещения удовлетворительное и позволяет использовать его '
                  'в целях, предусмотренных п. 1.1 указанного Договора аренды.')
    c.setFont(regular_font, 12)
    c.drawString(50, y, state_text)

    # Подписи
    y -= 60
    c.setFont(bold_font, 12)
    c.drawString(50, y, "Арендодатель:")
    c.drawString(width / 2 + 50, y, "Арендатор:")

    y -= 30
    c.setFont(regular_font, 12)

    # Вместо прямого использования c.drawImage, обработаем изображение через PIL
    signature_path = BASE_DIR / "resources" / "signature.png"

    if contract_data.get("owner_signed") and signature_path.exists():
        # Открываем изображение с PIL
        pil_image = Image.open(signature_path)

        # Конвертируем в режим RGBA если нужно
        if pil_image.mode != 'RGBA':
            pil_image = pil_image.convert('RGBA')

        # Создаем белый фон
        white_bg = Image.new('RGBA', pil_image.size, (255, 255, 255, 255))
        # Композитим изображение на белый фон
        combined = Image.alpha_composite(white_bg, pil_image)
        # Конвертируем обратно в RGB для сохранения
        combined = combined.convert('RGB')

        # Сохраняем во временный буфер
        img_buffer = io.BytesIO()
        combined.save(img_buffer, format='PNG')
        img_buffer.seek(0)

        # Рисуем обработанное изображение
        c.drawImage(ImageReader(img_buffer), 50, y - 40, width=100, height=40, preserveAspectRatio=True)
    else:
        c.drawString(50, y, '_______________')

    # Аналогично для подписи арендатора
    if contract_data.get("tenant_signed") and signature_path.exists():
        # Та же обработка для второго изображения
        pil_image = Image.open(signature_path)
        if pil_image.mode != 'RGBA':
            pil_image = pil_image.convert('RGBA')
        white_bg = Image.new('RGBA', pil_image.size, (255, 255, 255, 255))
        combined = Image.alpha_composite(white_bg, pil_image).convert('RGB')
        img_buffer = io.BytesIO()
        combined.save(img_buffer, format='PNG')
        img_buffer.seek(0)
        c.drawImage(ImageReader(img_buffer), width / 2 + 50, y - 40, width=100, height=40, preserveAspectRatio=True)
    else:
        c.drawString(width / 2 + 50, y, '_______________')

    y -= 20
    c.setFont(regular_font, 10)
    c.drawString(50, y, f'Паспорт: {owner_data.get("passport", "___________")}')
    c.drawString(width / 2 + 50, y, f'Паспорт: {tenant_data.get("passport", "___________")}')

    c.save()
    return output_path


def generate_agent_stats_excel(agent_id, months, monthly_data, perf_data, status_data):
    """Генерирует Excel-файл со статистикой агента"""
    from openpyxl import Workbook
    from openpyxl.chart import BarChart, PieChart, Reference
    import tempfile
    from pathlib import Path

    wb = Workbook()

    # Лист Monthly
    ws1 = wb.active
    ws1.title = "Monthly"
    ws1.append(["Месяц", "Сделки", "Прибыль", "Заявки", "Одобрено", "Отклонено"])

    for row in monthly_data:
        ws1.append([
            row.month,
            row.deals_count,
            float(row.total_profit) if row.total_profit else 0,
            row.applications_count,
            row.approved_count,
            row.rejected_count
        ])

    # Диаграмма прибыли по месяцам
    if len(monthly_data) > 0:
        chart = BarChart()
        chart.title = "Динамика прибыли"
        data = Reference(ws1, min_col=3, min_row=2, max_row=len(monthly_data) + 1)
        cats = Reference(ws1, min_col=1, min_row=2, max_row=len(monthly_data) + 1)
        chart.add_data(data, titles_from_data=False)
        chart.set_categories(cats)
        ws1.add_chart(chart, "H2")

    # Лист Performance
    ws2 = wb.create_sheet("Performance")
    ws2.append(["Показатель", "Значение"])
    if perf_data:
        ws2.append(["Общая прибыль", float(perf_data.total_profit) if perf_data.total_profit else 0])
        ws2.append(["Средняя прибыль на объект",
                    float(perf_data.avg_profit_per_property) if perf_data.avg_profit_per_property else 0])
        ws2.append(["Всего сделок", perf_data.total_deals])
        ws2.append(["Загрузка фонда (%)", float(perf_data.occupancy_rate) if perf_data.occupancy_rate else 0])
        ws2.append(["Обработано заявок", perf_data.processed_applications])
        ws2.append(
            ["Среднее время ответа (ч)", float(perf_data.avg_response_hours) if perf_data.avg_response_hours else 0])
        ws2.append(["Конверсия (%)", float(perf_data.conversion_rate) if perf_data.conversion_rate else 0])

    # Лист Status
    ws3 = wb.create_sheet("Status")
    ws3.append(["Статус", "Количество", "Процент"])
    for row in status_data:
        ws3.append([row.status, row.count, float(row.percentage) if row.percentage else 0])

    # Круговая диаграмма
    if len(status_data) > 0:
        pie = PieChart()
        pie.title = "Распределение по статусам"
        labels = Reference(ws3, min_col=1, min_row=2, max_row=len(status_data) + 1)
        data = Reference(ws3, min_col=2, min_row=2, max_row=len(status_data) + 1)
        pie.add_data(data, titles_from_data=False)
        pie.set_categories(labels)
        ws3.add_chart(pie, "E2")

    # Сохраняем во временный файл
    temp_dir = Path(__file__).parent / "temp"
    temp_dir.mkdir(exist_ok=True)

    import uuid
    filename = f"agent_stats_{agent_id}_{months}_{uuid.uuid4().hex}.xlsx"
    filepath = temp_dir / filename
    wb.save(str(filepath))

    return str(filepath)