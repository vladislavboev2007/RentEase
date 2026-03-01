// static/script.js

// Текущий режим отображения
let currentViewMode = 'grid';
let currentPropertyId = null;

// Глобальная инициализация
window.hasValidationErrors = false;
window.uploadedFiles = [];

console.log('🚀 script.js загружен, версия 2.0');

// ==================== УПРАВЛЕНИЕ МОДАЛЬНЫМИ ОКНАМИ ====================

function showCityPopup() {
    document.getElementById('cityPopup').style.display = 'flex';
}

function hideCityPopup() {
    document.getElementById('cityPopup').style.display = 'none';
}

function showGuidePopup() {
    document.getElementById('guidePopup').style.display = 'flex';
}

function hideGuidePopup() {
    document.getElementById('guidePopup').style.display = 'none';
}

function showLoginModal() {
    document.getElementById('loginModal').style.display = 'flex';
    setTimeout(() => document.getElementById('login-email')?.focus(), 100);
}

function hideLoginModal() {
    document.getElementById('loginModal').style.display = 'none';
}

// ==================== УПРАВЛЕНИЕ ФИЛЬТРАМИ ====================

function searchCity() {
    const searchText = document.getElementById('citySearch').value;
    if (searchText.length >= 2) {
        alert(`Поиск города: ${searchText}`);
    }
}

function resetFilters() {
    document.getElementById('search').value = '';
    document.getElementById('city').value = '';
    document.getElementById('property_type').value = 'all';
    document.getElementById('rooms').value = 'all';
    document.querySelector('input[name="min_price"]').value = '';
    document.querySelector('input[name="max_price"]').value = '';
    document.querySelector('input[name="min_area"]').value = '';
    document.querySelector('input[name="max_area"]').value = '';
    document.getElementById('searchForm').submit();
}

// ==================== СОРТИРОВКА И ОТОБРАЖЕНИЕ ====================

function changeSort(sortBy) {
    const container = document.getElementById('propertiesContainer');
    const cards = Array.from(container.getElementsByClassName('property-card'));

    cards.sort((a, b) => {
        const priceA = parseFloat(a.dataset.price);
        const priceB = parseFloat(b.dataset.price);
        const areaA = parseFloat(a.dataset.area) || 0;
        const areaB = parseFloat(b.dataset.area) || 0;
        const createdA = a.dataset.created ? new Date(a.dataset.created) : new Date(0);
        const createdB = b.dataset.created ? new Date(b.dataset.created) : new Date(0);

        switch (sortBy) {
            case 'price_asc':
                return priceA - priceB;
            case 'price_desc':
                return priceB - priceA;
            case 'area_asc':
                return areaA - areaB;
            case 'area_desc':
                return areaB - areaA;
            case 'newest':
                return createdB - createdA;
            default:
                return 0;
        }
    });

    cards.forEach(card => container.appendChild(card));
}

function setViewMode(mode) {
    if (mode === currentViewMode) return;

    const container = document.getElementById('propertiesContainer');
    const gridBtn = document.getElementById('gridViewBtn');
    const listBtn = document.getElementById('listViewBtn');

    if (mode === 'grid') {
        container.className = 'results-grid';
        gridBtn.classList.add('active');
        listBtn.classList.remove('active');
    } else {
        container.className = 'results-list';
        gridBtn.classList.remove('active');
        listBtn.classList.add('active');
    }

    currentViewMode = mode;
}

// ==================== УПРАВЛЕНИЕ МОДАЛЬНЫМ ОКНОМ ОБЪЕКТА ====================

function showPropertyDetails(propertyId) {
    currentPropertyId = propertyId;

    const modal = document.getElementById('propertyModal');
    const loader = document.getElementById('propertyModalLoader');
    const content = document.getElementById('propertyModalContent');

    modal.style.display = 'flex';
    loader.style.display = 'block';
    content.style.display = 'none';

    fetch(`/api/property/${propertyId}`)
        .then(response => {
            if (!response.ok) throw new Error('Ошибка загрузки данных');
            return response.json();
        })
        .then(data => {
            fillPropertyModal(data);
            loader.style.display = 'none';
            content.style.display = 'block';
        })
        .catch(error => {
            console.error('Ошибка:', error);
            loader.style.display = 'none';
            alert('Не удалось загрузить данные объекта');
            hidePropertyModal();
        });
}

function hidePropertyModal() {
    document.getElementById('propertyModal').style.display = 'none';
}

function fillPropertyModal(data) {
    document.getElementById('modalPropertyTitle').textContent = data.title || 'Без названия';

    const statusBadge = document.getElementById('modalPropertyStatus');
    statusBadge.textContent = data.status === 'active' ? 'Активно' :
        data.status === 'rented' ? 'Сдано' : 'В архиве';
    statusBadge.className = `property-status-badge status-${data.status || 'active'}`;

    document.getElementById('modalPropertyCity').textContent = data.city || '-';
    document.getElementById('modalPropertyAddress').textContent = data.address || '-';
    document.getElementById('modalPropertyArea').textContent = data.area ? `${data.area} м²` : '-';

    let propertyType = '-';
    if (data.property_type === 'apartment') propertyType = 'Квартира';
    else if (data.property_type === 'house') propertyType = 'Дом';
    else if (data.property_type === 'commercial') propertyType = 'Коммерческая';
    document.getElementById('modalPropertyType').textContent = propertyType;

    document.getElementById('modalPropertyRooms').textContent = data.rooms ? `${data.rooms} комн.` : '-';

    let priceText = data.price ? `${Number(data.price).toLocaleString('ru-RU')} ₽` : '-';
    if (data.interval_pay === 'month') priceText += '/мес';
    else if (data.interval_pay === 'week') priceText += '/нед';
    document.getElementById('modalPropertyPrice').textContent = priceText;

    document.getElementById('modalPropertyDescription').textContent = data.description || 'Нет описания';

    updateModalGallery(data.photos || []);

    if (data.owner) {
        document.getElementById('modalOwnerName').textContent = data.owner.full_name || 'Не указан';
        document.getElementById('modalOwnerEmail').textContent = data.owner.email || 'Не указан';
        const ownerPhone = data.owner.contact_info?.phone || 'Не указан';
        document.getElementById('modalOwnerPhone').textContent = ownerPhone;
    }

    if (data.agent) {
        document.getElementById('modalAgentName').textContent = data.agent.full_name || 'Не указан';
        document.getElementById('modalAgentEmail').textContent = data.agent.email || 'Не указан';
        const agentPhone = data.agent.contact_info?.phone || 'Не указан';
        document.getElementById('modalAgentPhone').textContent = agentPhone;
        document.getElementById('modalAgentInfo').style.display = 'block';
    } else {
        document.getElementById('modalAgentInfo').style.display = 'none';
    }
}

function updateModalGallery(photos) {
    const mainImage = document.getElementById('modalMainImageImg');
    const thumbnailContainer = document.getElementById('modalThumbnailContainer');

    if (photos && photos.length > 0) {
        mainImage.src = photos[0].url || '/static/placeholder-image.png';

        thumbnailContainer.innerHTML = '';
        photos.forEach((photo, index) => {
            const thumb = document.createElement('div');
            thumb.className = `modal-thumbnail ${index === 0 ? 'active' : ''}`;
            thumb.onclick = () => changeModalImage(photo.url, thumb);
            thumb.innerHTML = `<img src="${photo.url}" alt="Thumbnail ${index + 1}">`;
            thumbnailContainer.appendChild(thumb);
        });
    } else {
        mainImage.src = '/static/placeholder-image.png';
        thumbnailContainer.innerHTML = '';
    }
}

function changeModalImage(imageUrl, thumbnail) {
    document.getElementById('modalMainImageImg').src = imageUrl;

    document.querySelectorAll('.modal-thumbnail').forEach(thumb => {
        thumb.classList.remove('active');
    });
    thumbnail.classList.add('active');
}

function showContactForm() {
    if (!isUserLoggedIn()) {
        showNotification('Необходимо авторизоваться', 'warning');
        showLoginModal();
        return;
    }

    // Получаем ID агента или собственника из модального окна
    // (нужно добавить data-атрибуты)
    const agentId = document.getElementById('modalAgentId')?.value;
    const ownerId = document.getElementById('modalOwnerId')?.value;
    const userId = agentId || ownerId;
    const userName = agentId ? 'агентом' : 'собственником';

    if (userId) {
        openChat(parseInt(userId));
    } else {
        showNotification('Не удалось определить получателя', 'error');
    }
}

// Функция для показа формы подачи заявки
function showApplicationForm() {
    console.log('showApplicationFormFromModal вызван');

    if (!isUserLoggedIn()) {
        alert('Для подачи заявки необходимо войти в систему');
        showLoginModal();
        return;
    }

    if (!currentPropertyId) {
        showNotification('Ошибка: не указан объект', 'error');
        return;
    }

    // Получаем данные из модального окна объекта
    const titleEl = document.getElementById('modalPropertyTitle');
    const cityEl = document.getElementById('modalPropertyCity');
    const addressEl = document.getElementById('modalPropertyAddress');
    const priceEl = document.getElementById('modalPropertyPrice');
    const mainImageEl = document.getElementById('modalMainImageImg');

    // Формируем полный адрес с городом в начале
    const city = cityEl ? cityEl.textContent.trim() : '';
    const address = addressEl ? addressEl.textContent.trim() : '';
    const fullAddress = city ? `${city}, ${address}` : address;

    // Получаем цену
    const price = priceEl ? priceEl.textContent.trim() : 'Цена не указана';

    // Получаем главное фото
    const imageUrl = mainImageEl ? mainImageEl.src : '/resources/placeholder-image.png';

    // Заполняем форму подачи заявки
    document.getElementById('appPropertyId').value = currentPropertyId;
    document.getElementById('applicationPropertyTitle').textContent = titleEl ? titleEl.textContent.trim() : 'Объект';
    document.getElementById('applicationPropertyAddress').textContent = fullAddress || 'Адрес не указан';
    document.getElementById('applicationPropertyPrice').textContent = price;
    document.getElementById('applicationPropertyImage').src = imageUrl;

    // Устанавливаем минимальную дату - сегодня
    const today = new Date().toISOString().split('T')[0];
    const dateInput = document.getElementById('desiredDate');
    if (dateInput) {
        dateInput.min = today;
        dateInput.value = '';
    }

    // Устанавливаем длительность по умолчанию
    const durationInput = document.getElementById('durationDays');
    if (durationInput) {
        durationInput.value = '365';
    }

    // Очищаем сообщение
    const messageInput = document.getElementById('message');
    if (messageInput) {
        messageInput.value = '';
    }

    openModal('applicationSubmitModal');
}


// ==================== УПРАВЛЕНИЕ МЕНЮ ====================

function toggleUserMenu(event) {
    event.stopPropagation();
    const dropdown = document.getElementById('userDropdown');
    const dashboardDropdown = document.getElementById('dashboardDropdown');

    if (dashboardDropdown) dashboardDropdown.classList.remove('show');
    if (dropdown) dropdown.classList.toggle('show');
}

function toggleDashboardMenu(event) {
    event.stopPropagation();
    const dropdown = document.getElementById('dashboardDropdown');
    const userDropdown = document.getElementById('userDropdown');

    if (userDropdown) userDropdown.classList.remove('show');
    if (dropdown) dropdown.classList.toggle('show');
}

// ==================== ВЫХОД ИЗ АККАУНТА ====================

function logout() {
    console.log('logout вызван');
    if (!confirm('Вы действительно хотите выйти?')) return;

    fetch('/api/logout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin'
    })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                document.getElementById('userDropdown')?.classList.remove('show');
                document.getElementById('dashboardDropdown')?.classList.remove('show');
                showNotification('Вы успешно вышли из аккаунта', 'success');
                setTimeout(() => window.location.href = '/', 500);
            } else {
                showNotification('Ошибка при выходе', 'error');
            }
        })
        .catch(error => {
            console.error('Ошибка при выходе:', error);
            showNotification('Ошибка при выходе из аккаунта', 'error');
        });
}

// ==================== УВЕДОМЛЕНИЯ ====================

function showNotification(message, type = 'info') {
    const oldNotification = document.querySelector('.notification');
    if (oldNotification) oldNotification.remove();

    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => notification.classList.add('show'), 10);
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// ==================== ФУНКЦИИ ДЛЯ МОДАЛЬНЫХ ОКОН ====================

function showMyApplications() {
    console.log('showMyApplications вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadMyApplications(); // Загружаем свежие данные
    openModal('myApplicationsModal');
}

// ==================== ДОГОВОРЫ ====================

// Показать мои договоры
function showMyContracts() {
    console.log('showMyContracts вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadMyContracts();
    openModal('myContractsModal');
}

async function loadMyContracts() {
    try {
        const response = await fetch('/api/my/contracts', { credentials: 'same-origin' });
        if (!response.ok) {
            if (response.status === 401) {
                showNotification('Необходимо авторизоваться', 'warning');
                showLoginModal();
                return;
            }
            throw new Error('Ошибка загрузки');
        }

        const contracts = await response.json();
        console.log('Договоры:', contracts);

        const container = document.getElementById('myContractsList');
        if (!container) return;

        if (contracts.length === 0) {
            container.innerHTML = '<p style="text-align: center; padding: 40px; color: #6c757d;">У вас пока нет договоров</p>';
            return;
        }

        let html = '';
        for (const contract of contracts) {
            // Используем photo из ответа API
            const photoUrl = contract.property_photo || '/resources/placeholder-image.png';

            // Статус договора
            const statusConfig = {
                'draft': { bg: '#e9ecef', color: '#6c757d', text: 'Черновик' },
                'pending': { bg: '#fff3cd', color: '#856404', text: 'Ожидает подписи' },
                'signed': { bg: '#d4edda', color: '#155724', text: 'Подписан' }
            };
            const status = statusConfig[contract.signing_status] || { bg: '#e9ecef', color: '#6c757d', text: contract.signing_status };

            // Форматируем период
            const startDate = contract.start_date ? new Date(contract.start_date).toLocaleDateString('ru-RU') : '?';
            const endDate = contract.end_date ? new Date(contract.end_date).toLocaleDateString('ru-RU') : '?';

            // Форматируем сумму
            const amount = contract.total_amount ? Number(contract.total_amount).toLocaleString('ru-RU') : '0';

            html += `
                <div class="contract-item" onclick="showContractDetail(${contract.contract_id})" style="display: flex; gap: 15px; padding: 15px; border-bottom: 1px solid #e9ecef; cursor: pointer; align-items: center;">
                    <!-- Фото слева -->
                    <div style="width: 80px; height: 80px; flex-shrink: 0;">
                        <img src="${photoUrl}" style="width: 100%; height: 100%; object-fit: cover; border-radius: 8px;" onerror="this.src='/resources/placeholder-image.png'">
                    </div>

                    <!-- Информация по центру -->
                    <div style="flex: 1;">
                        <div style="font-weight: 700; font-size: 16px;">${contract.contract_number || 'Договор №' + contract.contract_id}</div>
                        <div style="color: #212529;">${contract.property_title || 'Без названия'}</div>
                        <div style="color: #6c757d; font-size: 14px;">Период: ${startDate} - ${endDate}</div>
                    </div>

                    <!-- Статус и цена справа -->
                    <div style="text-align: right;">
                        <div style="margin-bottom: 8px;">
                            <span style="padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${status.bg}; color: ${status.color};">${status.text}</span>
                        </div>
                        <div style="font-weight: 700; color: #28a745; font-size: 16px;">${amount} ₽</div>
                    </div>
                </div>
            `;
        }
        container.innerHTML = html;
    } catch (error) {
        console.error('Ошибка загрузки договоров:', error);
        showNotification('Ошибка загрузки договоров', 'error');
    }
}

async function showContractDetail(contractId) {
    try {
        const response = await fetch(`/api/contracts/${contractId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки договора');

        const contract = await response.json();
        console.log('Детали договора:', contract);

        // Сохраняем ID в dataset
        document.getElementById('contractDetailModal').dataset.contractId = contractId;

        // Фото объекта
        const photoUrl = contract.property_photo || '/resources/placeholder-image.png';
        document.getElementById('contractDetailImage').src = photoUrl;

        // Номер договора
        document.getElementById('contractDetailNumber').textContent = contract.contract_number || `Договор №${contract.contract_id}`;

        // Информация об объекте
        document.getElementById('contractDetailTitle').textContent = contract.property_title || 'Без названия';

        const fullAddress = contract.property_city ? `${contract.property_city}, ${contract.property_address}` : (contract.property_address || 'Адрес не указан');
        document.getElementById('contractDetailAddress').textContent = fullAddress;

        let propertyType = '';
        if (contract.property_type === 'apartment') propertyType = 'Квартира';
        else if (contract.property_type === 'house') propertyType = 'Дом';
        else if (contract.property_type === 'commercial') propertyType = 'Коммерческая';

        document.getElementById('contractDetailPropertyDetails').textContent =
            `${propertyType} • ${contract.property_rooms || '?'} комн. • ${contract.property_area || '?'} м²`;

        // Длительность
        if (contract.start_date && contract.end_date) {
            const start = new Date(contract.start_date);
            const end = new Date(contract.end_date);
            const diffTime = Math.abs(end - start);
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
            const diffMonths = Math.round(diffDays / 30);
            document.getElementById('contractDetailDuration').textContent = `${diffMonths} месяцев (${diffDays} дней)`;
        } else {
            document.getElementById('contractDetailDuration').textContent = '-';
        }

        // Даты
        const startDate = contract.start_date ? new Date(contract.start_date).toLocaleDateString('ru-RU') : '-';
        const endDate = contract.end_date ? new Date(contract.end_date).toLocaleDateString('ru-RU') : '-';
        const createdDate = contract.created_at ? new Date(contract.created_at).toLocaleDateString('ru-RU') : '-';

        document.getElementById('contractDetailStartDate').textContent = startDate;
        document.getElementById('contractDetailStartDate2').textContent = startDate;
        document.getElementById('contractDetailEndDate').textContent = endDate;
        document.getElementById('contractDetailCreated').textContent = createdDate;

        // Сумма
        const amount = contract.total_amount ? Number(contract.total_amount).toLocaleString('ru-RU') : '0';
        document.getElementById('contractDetailAmount').textContent = `${amount} ₽`;

        // Статус
        const statusConfig = {
            'draft': { bg: '#e9ecef', color: '#6c757d', text: 'Черновик' },
            'pending': { bg: '#fff3cd', color: '#856404', text: 'Ожидает подписи' },
            'signed': { bg: '#d4edda', color: '#155724', text: 'Подписан' }
        };
        const status = statusConfig[contract.signing_status] || { bg: '#e9ecef', color: '#6c757d', text: contract.signing_status };
        document.getElementById('contractDetailStatus').innerHTML = `<span style="padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${status.bg}; color: ${status.color};">${status.text}</span>`;

        // Информация о сторонах
        document.getElementById('contractDetailTenantName').textContent = contract.tenant_name || 'Не указан';
        document.getElementById('contractDetailTenantEmail').textContent = contract.tenant_email || '';
        document.getElementById('contractDetailOwnerName').textContent = contract.owner_name || 'Не указан';
        document.getElementById('contractDetailOwnerEmail').textContent = contract.owner_email || '';

        // Статусы подписания (упрощённо)
        // В реальности нужно добавить поля tenant_signed, owner_signed в модель

        // Показываем кнопку подписания, если статус не 'signed'
        const signButton = document.getElementById('contractSignButton');
        if (contract.signing_status !== 'signed') {
            signButton.style.display = 'block';
        } else {
            signButton.style.display = 'none';
        }

        closeModal('myContractsModal');
        openModal('contractDetailModal');

    } catch (error) {
        console.error('Ошибка загрузки деталей договора:', error);
        showNotification('Ошибка загрузки деталей договора', 'error');
    }
}

// Закрыть детали и вернуться к списку
function closeContractDetailAndShowList() {
    closeModal('contractDetailModal');
    showMyContracts();
}

// Подписать договор
async function signContract() {
    const contractId = document.getElementById('contractDetailModal').dataset.contractId;
    if (!contractId) {
        showNotification('Ошибка: не указан договор', 'error');
        return;
    }

    try {
        const response = await fetch(`/api/contracts/${contractId}/sign`, {
            method: 'POST',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка подписания');
        }

        showNotification('Договор подписан!', 'success');

        // Обновляем отображение
        showContractDetail(contractId);

        // Если открыт список, обновляем его
        if (document.getElementById('myContractsModal').style.display === 'flex') {
            loadMyContracts();
        }

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Заглушки для остальных функций
function cancelContract() {
    showNotification('Функция отмены договора будет доступна позже', 'info');
}

function downloadAct() {
    showNotification('Скачивание акта будет доступно позже', 'info');
}

function downloadContract() {
    showNotification('Скачивание договора будет доступно позже', 'info');
}

function showMyProperties() {
    console.log('showMyProperties вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadMyProperties();
    openModal('myPropertiesModal');
}

function showAgentStats() {
    console.log('showAgentStats вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadAgentStats();
    openModal('agentStatsModal');
}

function showProfileModal() {
    console.log('showProfileModal вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    loadUserProfile();
    openModal('profileModal');
}

// Заглушки для функций, которые могут быть вызваны, но ещё не реализованы
function showIncomingApplications() {
    console.log('showIncomingApplications');
    openModal('incomingApplicationsModal');
    // TODO: загрузить список входящих заявок
}

// Обновлённая функция показа деталей заявки
async function showApplicationDetail(applicationId) {
    try {
        const response = await fetch(`/api/applications/${applicationId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки данных заявки');
        const app = await response.json();

        // Сохраняем ID заявки в dataset модального окна
        document.getElementById('applicationDetailModal').dataset.applicationId = applicationId;

        // Получаем фото объекта
        let photoUrl = app.property_photo || '/resources/placeholder-image.png';

        // Заполняем детали
        document.getElementById('detailPropertyImage').src = photoUrl;
        document.getElementById('detailPropertyTitle').textContent = app.property_title || 'Без названия';

        // Формируем полный адрес с городом
        const fullAddress = app.property_city ? `${app.property_city}, ${app.property_address}` : (app.property_address || 'Адрес не указан');
        document.getElementById('detailPropertyAddress').textContent = fullAddress;

        document.getElementById('detailDuration').textContent = app.duration_days ? `${app.duration_days} дней` : '-';
        document.getElementById('detailDesiredDate').textContent = app.desired_date ? new Date(app.desired_date).toLocaleDateString('ru-RU') : '-';
        document.getElementById('detailCreated').textContent = app.created_at ? new Date(app.created_at).toLocaleDateString('ru-RU') : '-';
        document.getElementById('detailMessage').textContent = app.message || '-';
        document.getElementById('detailAnswer').textContent = app.answer || 'Ответ ещё не получен';

        // Статус
        const statusConfig = {
            pending: { bg: '#fff3cd', color: '#856404', text: 'На рассмотрении' },
            approved: { bg: '#d4edda', color: '#155724', text: 'Одобрена' },
            rejected: { bg: '#f8d7da', color: '#721c24', text: 'Отклонена' },
            cancelled: { bg: '#e9ecef', color: '#6c757d', text: 'Отменена' }
        };
        const status = statusConfig[app.status] || { bg: '#e9ecef', color: '#6c757d', text: app.status };
        document.getElementById('detailStatus').innerHTML = `<span style="padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${status.bg}; color: ${status.color};">${status.text}</span>`;

        // Цена с интервалом оплаты (зелёным цветом)
        let priceDisplay = 'Цена не указана';
        if (app.price && app.price > 0) {
            const formattedPrice = Number(app.price).toLocaleString('ru-RU');
            if (app.interval_pay === 'month') {
                priceDisplay = `${formattedPrice} ₽/мес`;
            } else if (app.interval_pay === 'week') {
                priceDisplay = `${formattedPrice} ₽/нед`;
            } else if (app.interval_pay === 'once') {
                priceDisplay = `${formattedPrice} ₽`;
            } else {
                priceDisplay = `${formattedPrice} ₽`;
            }
        }
        document.getElementById('detailPrice').textContent = priceDisplay;
        document.getElementById('detailPrice').style.color = '#28a745'; // Зелёный цвет

        closeModal('myApplicationsModal');
        openModal('applicationDetailModal');
    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка загрузки деталей заявки', 'error');
    }
}

// Функция для отмены заявки
async function cancelApplication(applicationId) {
    if (!confirm('Вы уверены, что хотите отменить заявку?')) return;

    try {
        const response = await fetch(`/api/applications/${applicationId}/cancel`, {
            method: 'POST',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка отмены заявки');
        }

        showNotification('Заявка отменена', 'success');
        loadMyApplications(); // Обновляем список
    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Функция для отмены из детального просмотра
function cancelApplicationFromDetail() {
    const appId = document.querySelector('#applicationDetailModal').dataset.applicationId;
    if (appId) {
        cancelApplication(appId);
        closeModal('applicationDetailModal');
    }
}

// Функция для закрытия деталей и возврата к списку заявок
function closeApplicationDetailAndShowMyApplications() {
    closeModal('applicationDetailModal');
    showMyApplications(); // Это откроет список заявок
}

function acceptApplication() {
    console.log('acceptApplication');
    // Можно автоматически отправить форму ответа с status=approved
}

function rejectApplication() {
    console.log('rejectApplication');
}

function goToContract() {
    console.log('goToContract');
    showNotification('Переход к договору в разработке', 'info');
}

// ==================== ЗАГРУЗКА ДАННЫХ ====================

// Функция для загрузки списка заявок (исходящих)
async function loadMyApplications() {
    try {
        const response = await fetch('/api/my/applications', { credentials: 'same-origin' });
        if (!response.ok) {
            if (response.status === 401) {
                showNotification('Необходимо авторизоваться', 'warning');
                showLoginModal();
                return;
            }
            throw new Error('Ошибка загрузки');
        }
        const applications = await response.json();
        console.log('Заявки:', applications);

        const container = document.getElementById('myApplicationsList');
        if (!container) return;

        if (applications.length === 0) {
            container.innerHTML = '<p style="text-align: center; padding: 40px; color: #6c757d;">У вас пока нет заявок</p>';
            return;
        }

        let html = '';
        for (const app of applications) {
            // Получаем фото объекта
            let photoUrl = '/resources/placeholder-image.png';
            try {
                const propResponse = await fetch(`/api/property/${app.property_id}`, { credentials: 'same-origin' });
                if (propResponse.ok) {
                    const propData = await propResponse.json();
                    if (propData.photos && propData.photos.length > 0) {
                        photoUrl = propData.photos[0].url;
                    }
                }
            } catch (e) {
                console.error('Ошибка загрузки фото:', e);
            }

            // Определяем статус
            const statusConfig = {
                pending: { bg: '#fff3cd', color: '#856404', text: 'На рассмотрении' },
                approved: { bg: '#d4edda', color: '#155724', text: 'Одобрена' },
                rejected: { bg: '#f8d7da', color: '#721c24', text: 'Отклонена' }
            };

            const status = statusConfig[app.status] || { bg: '#e9ecef', color: '#6c757d', text: app.status };

            // Форматируем дату
            const desiredDate = app.desired_date ? new Date(app.desired_date).toLocaleDateString('ru-RU') : 'не указана';

            // Формируем стоимость
            const priceDisplay = app.price ? `${Number(app.price).toLocaleString('ru-RU')} ₽/мес` : 'Цена не указана';

            html += `
                <div class="application-item" style="display: flex; gap: 15px; padding: 15px; border-bottom: 1px solid #e9ecef; align-items: center;">
                    <!-- Фото слева -->
                    <div style="width: 100px; height: 100px; flex-shrink: 0;">
                        <img src="${photoUrl}" alt="Property" style="width: 100%; height: 100%; object-fit: cover; border-radius: 8px;" onerror="this.src='/resources/placeholder-image.png'">
                    </div>

                    <!-- Информация по центру -->
                    <div style="flex: 1;">
                        <div style="font-weight: 700; font-size: 18px; margin-bottom: 5px;">${app.property_title || 'Без названия'}</div>
                        <div style="color: #6c757d; font-size: 14px; margin-bottom: 5px;">Длительность: ${app.duration_days || '?'} дней</div>
                        <div style="color: #6c757d; font-size: 14px; margin-bottom: 5px;">Желаемая дата: ${desiredDate}</div>
                        <div style="margin-bottom: 5px;">
                            <span style="padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${status.bg}; color: ${status.color};">${status.text}</span>
                        </div>
                        <div style="font-weight: 700; color: #28a745; font-size: 16px;">${priceDisplay}</div>
                    </div>

                    <!-- Кнопки справа -->
                    <div style="display: flex; flex-direction: column; gap: 8px; min-width: 160px;">
                        <button class="btn-info" onclick="showApplicationDetail(${app.application_id})" style="padding: 10px 12px; background: #17a2b8; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 500; display: flex; align-items: center; justify-content: center; gap: 5px;">
                            📋 Сведения о заявке
                        </button>
                        ${app.status === 'pending' ?
                            `<button class="btn-danger" onclick="cancelApplication(${app.application_id})" style="padding: 10px 12px; background: #dc3545; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 500; display: flex; align-items: center; justify-content: center; gap: 5px;">
                                🗑 Отменить заявку
                            </button>` :
                            ''
                        }
                    </div>
                </div>
            `;
        }
        container.innerHTML = html;
    } catch (error) {
        console.error('Ошибка загрузки заявок:', error);
        showNotification('Ошибка загрузки заявок', 'error');
    }
}


// ==================== ФОРМАТИРОВАНИЕ ЦЕНЫ ====================
function formatPrice(price, intervalPay) {
    const formattedPrice = Number(price).toLocaleString('ru-RU');
    switch(intervalPay) {
        case 'month':
            return `${formattedPrice} ₽/мес`;
        case 'week':
            return `${formattedPrice} ₽/нед`;
        case 'once':
            return `${formattedPrice} ₽`;
        default:
            return `${formattedPrice} ₽`;
    }
}

async function loadMyProperties() {
    console.log('loadMyProperties вызван');
    try {
        const response = await fetch('/api/my/properties', { credentials: 'same-origin' });
        if (!response.ok) {
            if (response.status === 401) {
                showNotification('Необходимо авторизоваться', 'warning');
                showLoginModal();
                return;
            }
            throw new Error('Ошибка загрузки');
        }
        const properties = await response.json();
        console.log('Объекты:', properties);

        const container = document.getElementById('myPropertiesList');
        if (!container) return;

        if (properties.length === 0) {
            container.innerHTML = '<p class="empty-list">У вас пока нет объектов</p>';
            return;
        }

        let html = '';
        properties.forEach(prop => {
            const priceDisplay = formatPrice(prop.price, prop.interval_pay);
            html += `
                <div class="property-item" style="display: flex; gap: 15px; padding: 15px; border-bottom: 1px solid #e9ecef;">
                    <img src="${prop.main_photo_url || '/resources/placeholder-image.png'}" alt="Property" style="width: 100px; height: 100px; object-fit: cover; border-radius: 8px;">
                    <div style="flex: 1;">
                        <div style="font-weight: 600; font-size: 18px;">${prop.title}</div>
                        <div style="color: #6c757d;">${prop.address}</div>
                        <div style="margin-top: 8px;">${prop.rooms} комн. • ${prop.area} м²</div>
                        <div style="display: flex; justify-content: space-between; margin-top: 8px; align-items: center;">
                            <span class="status-badge status-${prop.status}">${prop.status === 'active' ? 'Активно' : prop.status}</span>
                            <span style="font-weight: 600; color: #007bff;">${priceDisplay}</span>
                        </div>
                    </div>
                    <div style="display: flex; flex-direction: column; gap: 5px;">
                        <button class="btn-secondary" onclick="editProperty(${prop.property_id})">✎ Изменить</button>
                        <button class="btn-danger" onclick="deleteProperty(${prop.property_id})">× Удалить</button>
                    </div>
                </div>
            `;
        });
        container.innerHTML = html;
    } catch (error) {
        console.error('Ошибка загрузки объектов:', error);
        showNotification('Ошибка загрузки объектов', 'error');
    }
}

function loadAgentStats() {
    fetch('/api/agent/stats', { credentials: 'same-origin' })
        .then(response => response.json())
        .then(data => console.log('Статистика:', data))
        .catch(error => console.error('Ошибка загрузки статистики:', error));
}

// ==================== ВАЛИДАЦИЯ ====================

function validateEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
}

function validatePassword(password) {
    const errors = [];
    if (password.length < 8) {
        errors.push('Пароль должен быть не менее 8 символов');
    }
    if (!/[a-zA-Z]/.test(password)) {
        errors.push('Пароль должен содержать хотя бы одну букву');
    }
    if (!/\d/.test(password)) {
        errors.push('Пароль должен содержать хотя бы одну цифру');
    }
    return {
        isValid: errors.length === 0,
        errors: errors
    };
}

function validatePhone(phone) {
    if (!phone) return { isValid: true, message: '' };
    const digits = phone.replace(/\D/g, '');
    if (digits.length !== 11) {
        return { isValid: false, message: 'Номер должен содержать 11 цифр' };
    }
    if (digits[0] !== '7' && digits[0] !== '8') {
        return { isValid: false, message: 'Номер должен начинаться с 7 или 8' };
    }
    return { isValid: true, message: '' };
}

function validateInn(inn) {
    if (!inn) return { isValid: true, message: '' };
    const cleanInn = inn.replace(/\s/g, '');
    if (!/^\d+$/.test(cleanInn)) {
        return { isValid: false, message: 'ИНН должен содержать только цифры' };
    }
    if (cleanInn.length !== 10 && cleanInn.length !== 12) {
        return { isValid: false, message: 'ИНН должен быть 10 или 12 цифр' };
    }
    return { isValid: true, message: '' };
}

function validatePassport(passport) {
    if (!passport) return { isValid: true, message: '' };
    const cleanPassport = passport.replace(/\s/g, '');
    if (!/^\d+$/.test(cleanPassport)) {
        return { isValid: false, message: 'Паспорт должен содержать только цифры' };
    }
    if (cleanPassport.length !== 10) {
        return { isValid: false, message: 'Паспорт должен содержать 10 цифр (4 серия + 6 номер)' };
    }
    return { isValid: true, message: '' };
}

function validateBirthDate(dateStr) {
    if (!dateStr) return { isValid: true, message: '' };
    const birthDate = new Date(dateStr);
    const today = new Date();
    if (birthDate > today) {
        return { isValid: false, message: 'Дата рождения не может быть в будущем' };
    }
    const age = today.getFullYear() - birthDate.getFullYear();
    if (age < 18) {
        return { isValid: false, message: 'Вам должно быть не менее 18 лет' };
    }
    if (age > 120) {
        return { isValid: false, message: 'Проверьте корректность даты' };
    }
    return { isValid: true, message: '' };
}

function validateCity(city) {
    if (!city) return { isValid: true, message: '' };
    if (city.length < 2) {
        return { isValid: false, message: 'Название города слишком короткое' };
    }
    return { isValid: true, message: '' };
}

function showFieldError(inputElement, message) {
    const existingError = inputElement.parentNode.querySelector('.field-error');
    if (existingError) existingError.remove();
    inputElement.classList.add('error-field');
    window.hasValidationErrors = true;
    const errorDiv = document.createElement('div');
    errorDiv.className = 'field-error';
    errorDiv.textContent = message;
    errorDiv.style.color = '#dc3545';
    errorDiv.style.fontSize = '12px';
    errorDiv.style.marginTop = '4px';
    inputElement.parentNode.appendChild(errorDiv);
}

function clearFieldError(inputElement) {
    inputElement.classList.remove('error-field');
    const existingError = inputElement.parentNode.querySelector('.field-error');
    if (existingError) existingError.remove();
    checkGlobalErrors();
}

function checkGlobalErrors() {
    const errorFields = document.querySelectorAll('.error-field');
    window.hasValidationErrors = errorFields.length > 0;
    return window.hasValidationErrors;
}

function setupValidationListeners() {
    const phoneInput = document.getElementById('profilePhone');
    if (phoneInput) {
        phoneInput.addEventListener('input', function() {
            const result = validatePhone(this.value);
            result.isValid ? clearFieldError(this) : showFieldError(this, result.message);
        });
    }
    const innInput = document.getElementById('profileInn');
    if (innInput) {
        innInput.addEventListener('input', function() {
            const result = validateInn(this.value);
            result.isValid ? clearFieldError(this) : showFieldError(this, result.message);
        });
    }
    const passportInput = document.getElementById('profilePassport');
    if (passportInput) {
        passportInput.addEventListener('input', function() {
            const result = validatePassport(this.value);
            result.isValid ? clearFieldError(this) : showFieldError(this, result.message);
        });
    }
    const birthDateInput = document.getElementById('profileBirthDate');
    if (birthDateInput) {
        birthDateInput.addEventListener('blur', function() {
            const result = validateBirthDate(this.value);
            result.isValid ? clearFieldError(this) : showFieldError(this, result.message);
        });
    }
    const cityInput = document.getElementById('profileCity');
    if (cityInput) {
        cityInput.addEventListener('input', function() {
            const result = validateCity(this.value);
            result.isValid ? clearFieldError(this) : showFieldError(this, result.message);
        });
    }
}

// ==================== ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ ====================

async function loadUserProfile() {
    console.log('Загрузка профиля');
    try {
        const response = await fetch('/api/user/profile', { credentials: 'same-origin' });
        if (!response.ok) {
            if (response.status === 401) {
                showNotification('Необходимо авторизоваться', 'warning');
                closeModal('profileModal');
                showLoginModal();
                return;
            }
            throw new Error('Ошибка загрузки профиля');
        }
        const user = await response.json();
        console.log('Данные профиля:', user);

        const fullNameEl = document.getElementById('profileFullName');
        if (fullNameEl) fullNameEl.textContent = user.full_name || 'Не указано';
        const emailEl = document.getElementById('profileEmail');
        if (emailEl) emailEl.textContent = user.email || '';
        const birthDateEl = document.getElementById('profileBirthDate');
        if (birthDateEl) birthDateEl.value = user.contact_info?.birth_date || '';
        const cityEl = document.getElementById('profileCity');
        if (cityEl) cityEl.value = user.contact_info?.city || '';
        const phoneEl = document.getElementById('profilePhone');
        if (phoneEl) phoneEl.value = user.contact_info?.phone || '';
        const passportEl = document.getElementById('profilePassport');
        if (passportEl) passportEl.value = user.contact_info?.passport || '';
        const innEl = document.getElementById('profileInn');
        if (innEl) innEl.value = user.contact_info?.inn || '';
        const avatarEl = document.getElementById('profileAvatar');
        if (avatarEl) {
            avatarEl.src = user.avatar_url || '/resources/placeholder-avatar.png';
        }
        if (user.contact_info?.city) {
            updateHeaderCity(user.contact_info.city);
        }
        setupValidationListeners();
    } catch (error) {
        console.error('Ошибка загрузки профиля:', error);
        showNotification('Ошибка загрузки профиля', 'error');
    }
}

function updateHeaderCity(city) {
    const cityElement = document.getElementById('selectedCity');
    if (cityElement && city) cityElement.textContent = city;
}

function synchronizeCity() {
    const cityInput = document.getElementById('profileCity');
    if (!cityInput) return;
    const city = cityInput.value.trim();
    if (city) {
        updateHeaderCity(city);
        showNotification('Город в верхней панели обновлён', 'success');
    } else {
        showNotification('Введите город', 'warning');
    }
}

function updateHeaderAvatar(avatarUrl) {
    const avatarContainer = document.getElementById('userAvatarContainer');
    if (!avatarContainer) return;
    if (avatarUrl) {
        avatarContainer.innerHTML = `<img src="${avatarUrl}" alt="Avatar" class="user-avatar-img">`;
    } else {
        const initials = avatarContainer.dataset.initials || '?';
        avatarContainer.innerHTML = `<span class="user-initials">${initials}</span>`;
    }
}

// ==================== ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ ====================

function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.style.display = 'flex';
}

function closeModal(modalId) {
    if (modalId === 'profileModal' && window.hasValidationErrors) {
        if (!confirm('Есть неисправленные ошибки. Вы уверены, что хотите закрыть? Все изменения будут потеряны.')) {
            return;
        }
    }
    const modal = document.getElementById(modalId);
    if (modal) modal.style.display = 'none';
    if (modalId === 'profileModal') window.hasValidationErrors = false;
}

function isUserLoggedIn() {
    // Проверяем наличие меню пользователя (аватар)
    const userMenu = document.querySelector('.user-menu');
    // Или проверяем наличие аватара
    const userAvatar = document.querySelector('.user-avatar');
    // Или проверяем наличие скрытого поля с данными пользователя
    const isLoggedIn = document.body.hasAttribute('data-user-logged-in');

    // Простейший способ: проверить, есть ли элемент с классом .user-menu
    return !!document.querySelector('.user-menu');
}

// ==================== УПРАВЛЕНИЕ ЗАГРУЗКОЙ ФОТОГРАФИЙ ====================

const MAX_PHOTOS = 10;

function handlePhotoSelect(event) {
    const files = Array.from(event.target.files);
    if (!window.uploadedFiles) window.uploadedFiles = [];
    if (window.uploadedFiles.length + files.length > MAX_PHOTOS) {
        showNotification(`Можно загрузить не более ${MAX_PHOTOS} фотографий`, 'warning');
        return;
    }
    const validFiles = files.filter(file => file.type.startsWith('image/'));
    if (validFiles.length !== files.length) {
        showNotification('Некоторые файлы не являются изображениями и были пропущены', 'warning');
    }
    window.uploadedFiles.push(...validFiles);
    updatePhotoPreview();
    event.target.value = '';
}

function removePhoto(index) {
    if (window.uploadedFiles) {
        window.uploadedFiles.splice(index, 1);
        updatePhotoPreview();
    }
}

function formatFileSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function updatePhotoPreview() {
    const container = document.getElementById('photoPreviewContainer');
    const counter = document.getElementById('photoCounter');
    if (!container) return;
    if (counter) counter.textContent = `${window.uploadedFiles ? window.uploadedFiles.length : 0}/${MAX_PHOTOS}`;
    if (!window.uploadedFiles || window.uploadedFiles.length === 0) {
        container.innerHTML = '<div class="empty-preview">Фотографии не выбраны</div>';
        return;
    }
    let html = '';
    window.uploadedFiles.forEach((file, index) => {
        const url = URL.createObjectURL(file);
        html += `
            <div class="photo-preview-block">
                <div class="photo-preview-image">
                    <img src="${url}" alt="Preview" onload="URL.revokeObjectURL('${url}')">
                </div>
                <div class="photo-preview-info">
                    <div class="photo-preview-name">${file.name.length > 20 ? file.name.substring(0, 17) + '...' : file.name}</div>
                    <div class="photo-preview-size">${formatFileSize(file.size)}</div>
                </div>
                <button class="photo-preview-remove" onclick="removePhoto(${index})">×</button>
            </div>
        `;
    });
    container.innerHTML = html;
}

async function uploadPropertyPhotos(propertyId, files) {
    if (!files || files.length === 0) return [];
    console.log(`📸 Загрузка ${files.length} фотографий для объекта ID=${propertyId}`);
    const formData = new FormData();
    files.forEach(file => formData.append('photos', file));
    try {
        const response = await fetch(`/api/properties/${propertyId}/photos`, {
            method: 'POST',
            body: formData,
            credentials: 'same-origin'
        });
        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка загрузки фото');
        }
        const result = await response.json();
        console.log(`✅ Загружено ${result.uploaded} фотографий`);
        showNotification(`Загружено ${result.uploaded} фотографий`, 'success');
        return result;
    } catch (error) {
        console.error('❌ Ошибка загрузки фото:', error);
        showNotification('Ошибка при загрузке фотографий', 'error');
        throw error;
    }
}

// ==================== ДОБАВЛЕНИЕ / РЕДАКТИРОВАНИЕ ОБЪЕКТА ====================

function showAddPropertyModal() {
    console.log('🏠 showAddPropertyModal вызван');
    const form = document.getElementById('propertyEditForm');
    if (form) {
        form.reset();
        delete form.dataset.propertyId;
    }
    document.getElementById('propertyEditTitle').textContent = 'Добавление объекта';
    openModal('propertyEditModal');
}

async function editProperty(propertyId) {
    console.log('editProperty вызван для ID:', propertyId);
    try {
        const response = await fetch(`/api/property/${propertyId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Не удалось загрузить данные');
        const prop = await response.json();
        document.getElementById('propTitle').value = prop.title || '';
        document.getElementById('propDescription').value = prop.description || '';
        document.getElementById('propAddress').value = prop.address || '';
        document.getElementById('propCity').value = prop.city || '';
        document.getElementById('propType').value = prop.property_type || 'apartment';
        document.getElementById('propArea').value = prop.area || '';
        document.getElementById('propRooms').value = prop.rooms || '';
        document.getElementById('propPrice').value = prop.price || '';
        document.getElementById('propInterval').value = prop.interval_pay || 'month';
        if (prop.photos && prop.photos.length > 0) {
            console.log(`📸 Загружено ${prop.photos.length} существующих фотографий`);
            displayExistingPhotos(prop.photos);
        } else {
            document.getElementById('photoPreviewContainer').innerHTML = '<div class="empty-preview">Фотографии не загружены</div>';
        }
        window.uploadedFiles = [];
        document.getElementById('propertyEditForm').dataset.propertyId = propertyId;
        document.getElementById('propertyEditTitle').textContent = 'Редактирование объекта';
        openModal('propertyEditModal');
    } catch (error) {
        console.error(error);
        showNotification(error.message, 'error');
    }
}

function displayExistingPhotos(photos) {
    const container = document.getElementById('photoPreviewContainer');
    if (!container) return;
    if (!photos || photos.length === 0) {
        container.innerHTML = '<div class="empty-preview">Фотографии не загружены</div>';
        return;
    }
    let html = '';
    photos.forEach((photo, index) => {
        html += `
            <div class="photo-preview-block existing-photo">
                <div class="photo-preview-image">
                    <img src="${photo.url}" alt="Property photo" onerror="this.src='/resources/placeholder-image.png'">
                </div>
                <div class="photo-preview-info">
                    <div class="photo-preview-name">Фото ${index + 1}</div>
                    <div class="photo-preview-size">${photo.is_main ? '⭐ Главное' : ''}</div>
                </div>
            </div>
        `;
    });
    container.innerHTML = html;
}

async function deleteProperty(propertyId) {
    console.log('deleteProperty вызван для ID:', propertyId);
    if (!confirm('Вы уверены, что хотите удалить этот объект?')) return;
    try {
        const response = await fetch(`/api/properties/${propertyId}`, {
            method: 'DELETE',
            credentials: 'same-origin'
        });
        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка удаления');
        }
        showNotification('Объект удалён', 'success');
        if (document.getElementById('myPropertiesModal').style.display === 'flex') {
            loadMyProperties();
        }
    } catch (error) {
        console.error(error);
        showNotification(error.message, 'error');
    }
}

async function uploadAvatar(file) {
    if (!file) return;
    const formData = new FormData();
    formData.append('file', file);
    try {
        showNotification('Загрузка...', 'info');
        const response = await fetch('/api/user/avatar', {
            method: 'POST',
            body: formData,
            credentials: 'same-origin'
        });
        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка загрузки');
        }
        const data = await response.json();
        const avatarEl = document.getElementById('profileAvatar');
        if (avatarEl) avatarEl.src = data.url;
        updateHeaderAvatar(data.url);
        showNotification('Аватар успешно обновлён', 'success');
    } catch (error) {
        console.error('Ошибка загрузки аватара:', error);
        showNotification(error.message, 'error');
    }
}

async function deleteAvatar() {
    if (!confirm('Вы уверены, что хотите удалить фото профиля?')) return;
    try {
        const response = await fetch('/api/user/avatar', {
            method: 'DELETE',
            credentials: 'same-origin'
        });
        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка удаления');
        }
        document.getElementById('profileAvatar').src = '/resources/placeholder-avatar.png';
        const avatarContainer = document.getElementById('userAvatarContainer');
        if (avatarContainer) {
            const initials = avatarContainer.dataset.initials || '?';
            avatarContainer.innerHTML = `<span class="user-initials">${initials}</span>`;
        }
        showNotification('Аватар удалён', 'success');
    } catch (error) {
        console.error('Ошибка удаления аватара:', error);
        showNotification(error.message, 'error');
    }
}

// ==================== ЧАТ ====================

// Глобальная переменная для текущего chatId
let currentChatUserId = null;
let messagesRefreshInterval = null;

// Показать список диалогов
function showDialogsList() {
    console.log('showDialogsList вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadDialogsList();
    openModal('dialogsListModal');
}

async function loadDialogsList() {
    try {
        const response = await fetch('/api/my/dialogs', { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки');

        const dialogs = await response.json();
        console.log('Диалоги:', dialogs);

        const container = document.getElementById('dialogsList');
        if (!container) return;

        if (dialogs.length === 0) {
            container.innerHTML = '<p style="text-align: center; padding: 40px; color: #6c757d;">У вас пока нет диалогов</p>';
            return;
        }

        let html = '';
        for (const dialog of dialogs) {
            // Форматируем время последнего сообщения
            let lastTimeText = '';
            if (dialog.last_time) {
                const lastDate = new Date(dialog.last_time);
                const today = new Date();
                const yesterday = new Date(today);
                yesterday.setDate(yesterday.getDate() - 1);

                if (lastDate.toDateString() === today.toDateString()) {
                    lastTimeText = lastDate.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
                } else if (lastDate.toDateString() === yesterday.toDateString()) {
                    lastTimeText = 'вчера';
                } else {
                    lastTimeText = lastDate.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
                }
            }

            // СОЗДАЁМ avatarHtml ЗДЕСЬ
            let avatarHtml = '';
            if (dialog.avatar_url) {
                avatarHtml = `<img src="${dialog.avatar_url}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; this.parentNode.innerHTML='<span style=\'color: white; font-weight: 600; font-size: 18px;\'>${dialog.user_initials || '?'}</span>';">`;
            } else {
                avatarHtml = `<span style="color: white; font-weight: 600; font-size: 18px;">${dialog.user_initials || '?'}</span>`;
            }

            html += `
                <div class="dialog-item" data-user-id="${dialog.user_id}" onclick="openChat(${dialog.user_id})" style="display: flex; align-items: center; gap: 15px; padding: 15px; border-bottom: 1px solid #e9ecef; cursor: pointer; position: relative; transition: background 0.2s;" onmouseover="this.style.background='#f8f9fa'" onmouseout="this.style.background='white'">
                    <!-- Аватар с индикатором статуса -->
                    <div style="position: relative;">
                        <div class="dialog-avatar" style="width: 50px; height: 50px; border-radius: 50%; overflow: hidden; background: linear-gradient(135deg, #007bff, #0056b3); display: flex; align-items: center; justify-content: center;">
                            ${avatarHtml}
                        </div>
                        <span class="online-dot" data-user-id="${dialog.user_id}" style="position: absolute; bottom: 2px; right: 2px; width: 12px; height: 12px; border-radius: 50%; background: #6c757d; border: 2px solid white;"></span>
                    </div>

                    <!-- Информация о диалоге -->
                    <div class="dialog-info" style="flex: 1;">
                        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
                            <span class="dialog-name" style="font-weight: 600; font-size: 16px;">${dialog.user_name || 'Пользователь'}</span>
                            ${dialog.unread > 0 ? `<span style="background: #007bff; color: white; border-radius: 20px; padding: 2px 8px; font-size: 11px; font-weight: 600;">${dialog.unread}</span>` : ''}
                        </div>
                        <div class="dialog-last-message" style="color: ${dialog.unread > 0 ? '#212529' : '#6c757d'}; font-size: 14px; display: flex; justify-content: space-between;">
                            <span style="font-weight: ${dialog.unread > 0 ? '500' : 'normal'};">${dialog.last_message || 'Нет сообщений'}</span>
                            <span style="font-size: 11px; color: #999; margin-left: 10px;">${lastTimeText || ''}</span>
                        </div>
                    </div>

                    <!-- Кнопки действий -->
                    <div class="dialog-actions" style="display: flex; gap: 8px;">
                        <button class="icon-btn" onclick="openChat(${dialog.user_id}); event.stopPropagation();" style="background: none; border: none; cursor: pointer; padding: 8px; border-radius: 50%;" title="Открыть чат">
                            💬
                        </button>
                        <button class="icon-btn" onclick="deleteDialog(${dialog.user_id}); event.stopPropagation();" style="background: none; border: none; cursor: pointer; padding: 8px; border-radius: 50%;" title="Удалить диалог">
                            🗑️
                        </button>
                    </div>
                </div>
            `;
        }
        container.innerHTML = html;

        // Запрашиваем начальные статусы для всех диалогов
        for (const dialog of dialogs) {
            try {
                const statusResponse = await fetch(`/api/user/${dialog.user_id}/status`, { credentials: 'same-origin' });
                if (statusResponse.ok) {
                    const statusData = await statusResponse.json();
                    // Важно: обновляем статус сразу после загрузки
                    updateUserOnlineStatus(dialog.user_id, statusData.is_online);
                }
            } catch (e) {
                console.error(`Ошибка получения статуса для пользователя ${dialog.user_id}:`, e);
            }
        }

    } catch (error) {
        console.error('Ошибка загрузки диалогов:', error);
        showNotification('Ошибка загрузки диалогов', 'error');
    }
}

// Открыть чат с пользователем
async function openChat(userId) {
    console.log('openChat', userId);
    currentChatUserId = userId;

    try {
        // Получаем данные пользователя
        const response = await fetch(`/api/user/${userId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки данных пользователя');

        const userData = await response.json();
        console.log('Данные пользователя:', userData);

        // Обновляем шапку чата
        document.getElementById('chatUserName').textContent = userData.full_name || 'Пользователь';

        // Аватар в шапке
        const avatarContainer = document.getElementById('chatAvatarContainer');
        if (avatarContainer) {
            if (userData.avatar_url) {
                avatarContainer.innerHTML = `<img src="${userData.avatar_url}" style="width: 45px; height: 45px; border-radius: 50%; object-fit: cover;">`;
            } else {
                const initials = getInitials(userData.full_name) || userData.email?.[0]?.toUpperCase() || '?';
                avatarContainer.innerHTML = `<span style="color: white; font-weight: 600; font-size: 16px;">${initials}</span>`;
            }
        }

        // Получаем актуальный статус через отдельный запрос
        try {
            const statusResponse = await fetch(`/api/user/${userId}/status`, { credentials: 'same-origin' });
            if (statusResponse.ok) {
                const statusData = await statusResponse.json();
                updateUserStatus(statusData.is_online);
            }
        } catch (e) {
            console.error('Ошибка получения статуса:', e);
            updateUserStatus(false);
        }

    } catch (error) {
        console.error('Ошибка загрузки данных пользователя:', error);
        document.getElementById('chatUserName').textContent = 'Пользователь';
        updateUserStatus(false);
    }

    // Загружаем сообщения
    await loadMessages(userId);

    closeModal('dialogsListModal');
    openModal('chatModal');
}

// Проверка статуса через REST API (запасной вариант)
async function checkUserStatus(userId) {
    try {
        const response = await fetch(`/api/user/${userId}/status`, { credentials: 'same-origin' });
        if (response.ok) {
            const data = await response.json();
            return data.is_online;
        }
    } catch (error) {
        console.error('Ошибка проверки статуса:', error);
    }
    return false;
}

// Загрузить сообщения
async function loadMessages(userId) {
    try {
        const response = await fetch(`/api/messages?chat_with=${userId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки сообщений');

        const data = await response.json();
        console.log('Сообщения:', data);

        const messagesContainer = document.getElementById('chatMessages');
        if (!messagesContainer) return;

        if (!data.messages || data.messages.length === 0) {
            messagesContainer.innerHTML = '<p style="text-align: center; padding: 40px; color: #6c757d;">Пусто</p>';
            return;
        }

        let html = '';
        let currentDate = null;

        data.messages.forEach(msg => {
            const msgDate = new Date(msg.created_at);
            const msgDateStr = msgDate.toDateString();

            // Добавляем разделитель дня, если день изменился
            if (msgDateStr !== currentDate) {
                currentDate = msgDateStr;
                html += getDateSeparator(msgDate);
            }

            if (msg.is_mine) {
                // Моё сообщение (справа)
                html += `
                    <div style="display: flex; justify-content: flex-end; margin-bottom: 5px;">
                        <div style="background: #007bff; color: white; padding: 10px 15px; border-radius: 18px 18px 4px 18px; max-width: 70%; word-wrap: break-word;">
                            ${msg.content}
                            <div style="font-size: 11px; opacity: 0.7; text-align: right; margin-top: 4px;">${formatMessageTime(msg.created_at)}</div>
                        </div>
                    </div>
                `;
            } else {
                // Сообщение собеседника (слева)
                html += `
                    <div style="display: flex; justify-content: flex-start; margin-bottom: 5px;">
                        <div style="background: white; padding: 10px 15px; border-radius: 18px 18px 18px 4px; max-width: 70%; box-shadow: 0 1px 2px rgba(0,0,0,0.1); word-wrap: break-word;">
                            ${msg.content}
                            <div style="font-size: 11px; color: #6c757d; margin-top: 4px;">${formatMessageTime(msg.created_at)}</div>
                        </div>
                    </div>
                `;
            }
        });

        messagesContainer.innerHTML = html;

        // Прокручиваем вниз
        const container = document.getElementById('chatMessagesContainer');
        if (container) {
            container.scrollTop = container.scrollHeight;
        }

    } catch (error) {
        console.error('Ошибка загрузки сообщений:', error);
        showNotification('Ошибка загрузки сообщений', 'error');
    }
}

// Функция для разделителя дней
function getDateSeparator(date) {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    let dateText = '';

    if (date.toDateString() === today.toDateString()) {
        dateText = 'Сегодня';
    } else if (date.toDateString() === yesterday.toDateString()) {
        dateText = 'Вчера';
    } else {
        // Форматируем дату: "28 февраля" или "27 февраля 2025 г."
        const now = new Date();
        const diffYears = now.getFullYear() - date.getFullYear();

        if (diffYears === 0) {
            // В этом году: "28 февраля"
            dateText = date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' });
        } else {
            // Больше года назад: "27 февраля 2025 г."
            dateText = date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' }) + ' г.';
        }
    }

    return `
        <div style="display: flex; justify-content: center; margin: 15px 0;">
            <span style="background: rgba(0,0,0,0.05); padding: 5px 15px; border-radius: 20px; font-size: 12px; color: #6c757d;">
                ${dateText}
            </span>
        </div>
    `;
}

// Форматирование времени сообщения
function formatMessageTime(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
}

// Получить инициалы из ФИО
function getInitials(fullName) {
    if (!fullName) return null;
    const parts = fullName.split(' ');
    if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return fullName[0].toUpperCase();
}

// Запустить периодическое обновление сообщений
function startMessagesRefresh(userId) {
    if (messagesRefreshInterval) {
        clearInterval(messagesRefreshInterval);
    }
    // Обновляем каждые 2 секунды вместо 5
    messagesRefreshInterval = setInterval(() => {
        if (currentChatUserId === userId) {
            loadMessages(userId);
        }
    }, 2000);
}
// Остановить обновление сообщений
function stopMessagesRefresh() {
    if (messagesRefreshInterval) {
        clearInterval(messagesRefreshInterval);
        messagesRefreshInterval = null;
    }
}

// Закрыть чат
function closeChat() {
    stopMessagesRefresh();
    currentChatUserId = null;
    closeModal('chatModal');
    showDialogsList(); // Возвращаемся к списку диалогов
}

// Отправить сообщение
async function sendMessage(toUserId, content) {
    if (!content.trim()) return;

    try {
        const response = await fetch('/api/messages', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                to_user_id: toUserId,
                content: content.trim()
            }),
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка отправки');
        }

        // Очищаем поле ввода
        document.getElementById('messageInput').value = '';

        // Обновляем сообщения
        await loadMessages(toUserId);

    } catch (error) {
        console.error('Ошибка отправки сообщения:', error);
        showNotification(error.message, 'error');
    }
}

// Удалить диалог
async function deleteDialog(userId) {
    if (!confirm('Вы уверены, что хотите удалить этот диалог?')) return;

    try {
        const response = await fetch(`/api/dialogs/${userId}`, {
            method: 'DELETE',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка удаления');
        }

        showNotification('Диалог удалён', 'success');
        loadDialogsList(); // Обновляем список

    } catch (error) {
        console.error('Ошибка удаления диалога:', error);
        showNotification(error.message, 'error');
    }
}

// Функция для связи (вызывается из модалки объекта)
async function contactUser(userId, userName) {
    if (!isUserLoggedIn()) {
        showNotification('Необходимо авторизоваться', 'warning');
        showLoginModal();
        return;
    }

    // Открываем чат с этим пользователем
    await openChat(userId);
}

// ==================== WEBSOCKET ДЛЯ ОНЛАЙН СТАТУСА ====================

let socket = null;
let currentUserId = null;

// Получить ID текущего пользователя (нужно добавить в шаблон)
function getCurrentUserId() {
    // Можно получить из глобальной переменной или из data-атрибута
    return window.currentUserId; // Нужно добавить в шаблон
}

// Инициализация WebSocket соединения
function initWebSocket() {
    const userId = getCurrentUserId();
    if (!userId) return;

    currentUserId = userId;

    // Закрываем предыдущее соединение если есть
    if (socket) {
        socket.close();
    }

    // Создаём новое соединение
    socket = new WebSocket(`ws://${window.location.host}/ws/${userId}`);

    socket.onopen = function(event) {
        console.log('WebSocket соединение установлено');
        // Отправляем ping каждые 30 секунд для поддержания соединения
        setInterval(() => {
            if (socket && socket.readyState === WebSocket.OPEN) {
                socket.send('ping');
            }
        }, 30000);
    };

    socket.onmessage = function(event) {
    console.log('WebSocket сообщение:', event.data);

        // Проверяем, является ли сообщение JSON
        if (event.data.startsWith('{')) {
            try {
                const data = JSON.parse(event.data);
                if (data.type === 'status_update') {
                    updateUserOnlineStatus(data.user_id, data.is_online);
                }
            } catch (e) {
                console.error('Ошибка парсинга JSON:', e);
            }
        } else {
            console.log('Получено не-JSON сообщение:', event.data);
            // Игнорируем pong и другие не-JSON сообщения
        }
    };

    socket.onclose = function(event) {
        console.log('WebSocket соединение закрыто');
        // Пытаемся переподключиться через 5 секунд
        setTimeout(() => {
            if (document.visibilityState === 'visible') {
                initWebSocket();
            }
        }, 5000);
    };

    socket.onerror = function(error) {
        console.error('WebSocket ошибка:', error);
    };
}

// Обновление статуса пользователя в интерфейсе
function updateUserOnlineStatus(userId, isOnline) {
    console.log(`🟢 Обновление статуса пользователя ${userId}: ${isOnline ? 'онлайн' : 'офлайн'}`);

    // 1. Обновляем статус в списке диалогов
    const dialogElement = document.querySelector(`.dialog-item[data-user-id="${userId}"]`);
    if (dialogElement) {
        const statusDot = dialogElement.querySelector('.online-dot');
        if (statusDot) {
            statusDot.style.background = isOnline ? '#28a745' : '#6c757d';
            console.log(`   ✅ Статус диалога обновлён: ${isOnline ? 'зелёный' : 'серый'}`);
        }
    }

    // 2. Обновляем статус в открытом чате
    if (currentChatUserId === userId) {
        console.log(`   💬 Обновление статуса в открытом чате для пользователя ${userId}`);
        updateUserStatus(isOnline);
    }
}

// Обновление статуса в шапке чата
function updateUserStatus(isOnline) {
    const statusEl = document.getElementById('chatUserStatus');
    if (!statusEl) {
        console.error('❌ Элемент chatUserStatus не найден');
        return;
    }

    if (isOnline) {
        statusEl.innerHTML = `
            <span style="width: 8px; height: 8px; border-radius: 50%; background: #28a745; display: inline-block;"></span>
            <span style="color: #28a745;">В сети</span>
        `;
    } else {
        statusEl.innerHTML = `
            <span style="width: 8px; height: 8px; border-radius: 50%; background: #6c757d; display: inline-block;"></span>
            <span style="color: #6c757d;">Не в сети</span>
        `;
    }
}

// Добавьте в startMessagesRefresh обновление статуса
function startMessagesRefresh(userId) {
    if (messagesRefreshInterval) {
        clearInterval(messagesRefreshInterval);
    }

    messagesRefreshInterval = setInterval(async () => {
        if (currentChatUserId === userId) {
            // Обновляем сообщения
            await loadMessages(userId);

            // Обновляем статус
            try {
                const statusResponse = await fetch(`/api/user/${userId}/status`, { credentials: 'same-origin' });
                if (statusResponse.ok) {
                    const statusData = await statusResponse.json();
                    updateUserStatus(statusData.is_online);
                }
            } catch (e) {
                console.error('Ошибка обновления статуса:', e);
            }
        }
    }, 10000); // Каждые 10 секунд
}

// Запуск при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    // Получаем ID пользователя из data-атрибута или глобальной переменной
    const userElement = document.getElementById('user-data');
    if (userElement) {
        window.currentUserId = userElement.dataset.userId;
        initWebSocket();
    }
});

// Переподключение при возвращении на страницу
document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible' && !socket) {
        initWebSocket();
    }
});

// ==================== ОБРАБОТЧИКИ СОБЫТИЙ ====================

document.addEventListener('DOMContentLoaded', function() {
    if (window._initialized) return;
    window._initialized = true;

    console.log('DOM загружен, инициализация...');

    // Инициализация счетчика объектов
    const count = document.querySelectorAll('.property-card').length;
    const totalCountEl = document.getElementById('totalCount');
    if (totalCountEl) totalCountEl.textContent = count;

    // Автодополнение городов с дебаунсом
    const cityInput = document.getElementById('city');
    const datalist = document.getElementById('citySuggestions');
    if (cityInput) {
        let timeout;
        cityInput.addEventListener('input', function() {
            clearTimeout(timeout);
            timeout = setTimeout(() => {
                if (this.value.length >= 2) {
                    fetch(`/api/cities/search?query=${encodeURIComponent(this.value)}`)
                        .then(response => response.json())
                        .then(cities => {
                            datalist.innerHTML = '';
                            cities.forEach(city => {
                                const option = document.createElement('option');
                                option.value = city;
                                datalist.appendChild(option);
                            });
                        })
                        .catch(error => console.error('Ошибка поиска городов:', error));
                }
            }, 300);
        });
    }

    // Выбор города из попапа
    document.querySelectorAll('.city-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const city = this.textContent;
            document.getElementById('selectedCity').textContent = city;
            const cityInput = document.getElementById('city');
            if (cityInput) cityInput.value = city;
            hideCityPopup();
        });
    });

    // Форма входа
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            const email = document.getElementById('login-email').value;
            const password = document.getElementById('login-password').value;
            const formData = new FormData();
            formData.append('email', email);
            formData.append('password', password);
            try {
                const response = await fetch('/api/login', {
                    method: 'POST',
                    body: formData,
                    credentials: 'same-origin'
                });
                const data = await response.json();
                if (data.success) {
                    showNotification('Вход выполнен успешно!', 'success');
                    hideLoginModal();
                    setTimeout(() => window.location.reload(), 500);
                } else {
                    showNotification(data.message || 'Ошибка при входе', 'error');
                }
            } catch (error) {
                console.error('Ошибка:', error);
                showNotification('Ошибка при входе', 'error');
            }
        });
    }

    // Загрузка города из профиля при загрузке страницы
    const cityElement = document.getElementById('selectedCity');
    if (cityElement && cityElement.textContent === 'Москва') {
        fetch('/api/user/profile', { credentials: 'same-origin' })
            .then(res => res.json())
            .then(user => {
                if (user.contact_info?.city) {
                    cityElement.textContent = user.contact_info.city;
                }
            })
            .catch(err => console.error('Ошибка загрузки города:', err));
    }

    // ========== ПРИВЯЗКА ОБРАБОТЧИКОВ ФОРМ ==========
    // (перенесены из глобальной области)

    // Форма добавления/редактирования объекта
    const propertyEditForm = document.getElementById('propertyEditForm');
    if (propertyEditForm) {
        propertyEditForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            console.log('📝 Форма отправлена');

            if (window._submitting) {
                console.log('⏳ Форма уже отправляется');
                return;
            }
            window._submitting = true;

            const dashboardBtn = document.querySelector('.dashboard-btn');
            if (!dashboardBtn) {
                showNotification('У вас нет прав для создания объектов', 'error');
                window._submitting = false;
                return;
            }

            const requiredFields = ['propTitle', 'propAddress', 'propCity', 'propType', 'propArea', 'propPrice', 'propInterval'];
            const fieldValues = {};

            for (let fieldId of requiredFields) {
                const field = document.getElementById(fieldId);
                if (!field || !field.value.trim()) {
                    showNotification(`Заполните поле ${fieldId.replace('prop', '')}`, 'error');
                    window._submitting = false;
                    return;
                }
                fieldValues[fieldId] = field.value.trim();
            }

            const filesToUpload = window.uploadedFiles ? [...window.uploadedFiles] : [];

            const formData = new FormData();
            formData.append('title', fieldValues.propTitle);
            formData.append('description', document.getElementById('propDescription')?.value.trim() || '');
            formData.append('address', fieldValues.propAddress);
            formData.append('city', fieldValues.propCity);
            formData.append('property_type', fieldValues.propType);
            formData.append('area', fieldValues.propArea);
            formData.append('rooms', document.getElementById('propRooms')?.value || 0);
            formData.append('price', fieldValues.propPrice);
            formData.append('interval_pay', fieldValues.propInterval);

            const propertyId = propertyEditForm.dataset.propertyId;
            const isEditing = !!propertyId;
            const url = isEditing ? `/api/properties/${propertyId}` : '/api/properties';
            const method = isEditing ? 'PUT' : 'POST';

            console.log(`📤 ${isEditing ? 'Обновление' : 'Создание'} объекта...`);

            try {
                const response = await fetch(url, {
                    method: method,
                    body: formData,
                    credentials: 'same-origin'
                });

                const responseText = await response.text();
                console.log('📥 Ответ сервера:', responseText);

                if (!response.ok) {
                    let errorMsg = 'Ошибка сохранения';
                    try {
                        const err = JSON.parse(responseText);
                        errorMsg = err.detail || errorMsg;
                    } catch (e) {
                        errorMsg = responseText || errorMsg;
                    }
                    throw new Error(errorMsg);
                }

                const result = JSON.parse(responseText);
                const newPropertyId = result.property_id || propertyId;

                showNotification(isEditing ? 'Объект обновлён' : 'Объект создан', 'success');

                if (!isEditing && filesToUpload.length > 0) {
                    console.log(`📸 Загружаем ${filesToUpload.length} фотографий для объекта ID=${newPropertyId}`);
                    showNotification('Загрузка фотографий...', 'info');
                    await uploadPropertyPhotos(newPropertyId, filesToUpload);
                }

                if (isEditing && filesToUpload.length > 0) {
                    console.log(`📸 Добавляем ${filesToUpload.length} новых фотографий к объекту ID=${propertyId}`);
                    showNotification('Загрузка новых фотографий...', 'info');
                    await uploadPropertyPhotos(propertyId, filesToUpload);
                }

                propertyEditForm.reset();
                delete propertyEditForm.dataset.propertyId;
                window.uploadedFiles = [];
                updatePhotoPreview();

                closeModal('propertyEditModal');

                if (document.getElementById('myPropertiesModal').style.display === 'flex') {
                    loadMyProperties();
                }
            } catch (error) {
                console.error('❌ Ошибка:', error);
                showNotification(error.message, 'error');
            } finally {
                window._submitting = false;
            }
        });
    }

    // Форма подачи заявки
    const applicationForm = document.getElementById('applicationForm');
    if (applicationForm) {
    applicationForm.addEventListener('submit', async function(e) {
        e.preventDefault();
        console.log('📝 Отправка заявки...');

        const propertyId = document.getElementById('appPropertyId').value;
        if (!propertyId) {
            showNotification('Ошибка: не указан объект', 'error');
            return;
        }

        const desiredDate = document.getElementById('desiredDate').value;
        const durationDays = parseInt(document.getElementById('durationDays').value) || 0;
        const message = document.getElementById('message').value;

        // Валидация
        if (!desiredDate) {
            showNotification('Укажите желаемую дату заселения', 'error');
            return;
        }

        if (durationDays <= 0) {
            showNotification('Укажите корректную длительность аренды (больше 0)', 'error');
            return;
        }

        const formData = {
            property_id: parseInt(propertyId),
            desired_date: desiredDate,
            duration_days: durationDays,
            message: message || ''  // Если сообщение пустое, отправляем пустую строку
        };

        console.log('Отправляемые данные:', formData);

        try {
            const response = await fetch('/api/applications', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(formData),
                credentials: 'same-origin'
            });

            const responseText = await response.text();
            console.log('Ответ сервера:', responseText);

            if (!response.ok) {
                let errorMsg = 'Ошибка подачи заявки';
                try {
                    const err = JSON.parse(responseText);
                    errorMsg = err.detail || err.message || errorMsg;
                } catch (e) {
                    errorMsg = responseText || errorMsg;
                }
                throw new Error(errorMsg);
            }

            const result = JSON.parse(responseText);
            console.log('✅ Заявка создана:', result);

            showNotification('Заявка успешно отправлена!', 'success');
            closeModal('applicationSubmitModal');

            // Если открыто модальное окно с заявками, обновляем его
            if (document.getElementById('myApplicationsModal').style.display === 'flex') {
                loadMyApplications();
            }

        } catch (error) {
            console.error('❌ Ошибка:', error);
            showNotification(error.message, 'error');
        }
    });

        // В секции DOMContentLoaded добавьте:
    const sendMessageForm = document.getElementById('sendMessageForm');
    if (sendMessageForm) {
        sendMessageForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            if (!currentChatUserId) {
                showNotification('Ошибка: не выбран чат', 'error');
                return;
            }
            const message = document.getElementById('messageInput').value;
            await sendMessage(currentChatUserId, message);
        });
    }
}

    // ========== ФОРМА ПРОФИЛЯ ==========
    const profileForm = document.getElementById('profileForm');
    if (profileForm) {
        profileForm.addEventListener('submit', async function(e) {
            e.preventDefault();
            console.log('💾 Сохранение профиля...');

            window.hasValidationErrors = false;
            let hasErrors = false;

            const phoneInput = document.getElementById('profilePhone');
            if (phoneInput && phoneInput.value) {
                const phoneValid = validatePhone(phoneInput.value);
                if (!phoneValid.isValid) {
                    showFieldError(phoneInput, phoneValid.message);
                    hasErrors = true;
                } else {
                    clearFieldError(phoneInput);
                }
            }

            const innInput = document.getElementById('profileInn');
            if (innInput && innInput.value) {
                const innValid = validateInn(innInput.value);
                if (!innValid.isValid) {
                    showFieldError(innInput, innValid.message);
                    hasErrors = true;
                } else {
                    clearFieldError(innInput);
                }
            }

            const passportInput = document.getElementById('profilePassport');
            if (passportInput && passportInput.value) {
                const passportValid = validatePassport(passportInput.value);
                if (!passportValid.isValid) {
                    showFieldError(passportInput, passportValid.message);
                    hasErrors = true;
                } else {
                    clearFieldError(passportInput);
                }
            }

            const birthDateInput = document.getElementById('profileBirthDate');
            if (birthDateInput && birthDateInput.value) {
                const birthValid = validateBirthDate(birthDateInput.value);
                if (!birthValid.isValid) {
                    showFieldError(birthDateInput, birthValid.message);
                    hasErrors = true;
                } else {
                    clearFieldError(birthDateInput);
                }
            }

            const cityInput = document.getElementById('profileCity');
            if (cityInput && cityInput.value) {
                const cityValid = validateCity(cityInput.value);
                if (!cityValid.isValid) {
                    showFieldError(cityInput, cityValid.message);
                    hasErrors = true;
                } else {
                    clearFieldError(cityInput);
                }
            }

            if (hasErrors) {
                showNotification('❌ Исправьте ошибки в форме перед сохранением', 'error');
                return;
            }

            const formData = new FormData();

            const fullNameEl = document.getElementById('profileFullName');
            if (fullNameEl) {
                formData.append('full_name', fullNameEl.textContent || '');
            }

            const fields = [
                { id: 'profileBirthDate', name: 'birth_date' },
                { id: 'profileCity', name: 'city' },
                { id: 'profilePhone', name: 'phone' },
                { id: 'profilePassport', name: 'passport' },
                { id: 'profileInn', name: 'inn' }
            ];

            fields.forEach(field => {
                const el = document.getElementById(field.id);
                if (el) {
                    formData.append(field.name, el.value || '');
                }
            });

            console.log('📤 Отправляемые данные:');
            for (let [key, value] of formData.entries()) {
                console.log(`   ${key}: ${value}`);
            }

            try {
                const response = await fetch('/api/user/profile', {
                    method: 'PUT',
                    body: formData,
                    credentials: 'same-origin'
                });

                const responseText = await response.text();
                console.log('📥 Статус ответа:', response.status);
                console.log('📥 Ответ сервера:', responseText);

                if (!response.ok) {
                    let errorMsg = 'Ошибка сохранения';
                    try {
                        const err = JSON.parse(responseText);
                        errorMsg = err.detail || JSON.stringify(err);
                    } catch (e) {
                        errorMsg = responseText || errorMsg;
                    }
                    throw new Error(errorMsg);
                }

                const result = JSON.parse(responseText);
                console.log('✅ Успех:', result);

                const city = document.getElementById('profileCity')?.value.trim();
                if (city) {
                    updateHeaderCity(city);
                }

                closeModal('profileModal');
                showNotification('✅ Профиль успешно обновлён!', 'success');

            } catch (error) {
                console.error('❌ Ошибка:', error);
                showNotification('❌ ' + error.message, 'error');
            }
        });
    }
});

// Обновление статуса пользователя
function updateUserStatus(isOnline, lastSeen) {
    const statusEl = document.getElementById('chatUserStatus');
    if (isOnline) {
        statusEl.innerHTML = `
            <span style="width: 8px; height: 8px; border-radius: 50%; background: #28a745; display: inline-block;"></span>
            <span style="color: #28a745;">В сети</span>
        `;
    } else {
        let lastSeenText = 'недавно';
        if (lastSeen) {
            const lastDate = new Date(lastSeen);
            const now = new Date();
            const diffMinutes = Math.floor((now - lastDate) / (1000 * 60));

            if (diffMinutes < 1) lastSeenText = 'только что';
            else if (diffMinutes < 60) lastSeenText = `${diffMinutes} мин. назад`;
            else if (diffMinutes < 1440) lastSeenText = `${Math.floor(diffMinutes / 60)} ч. назад`;
            else lastSeenText = lastDate.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
        }

        statusEl.innerHTML = `
            <span style="width: 8px; height: 8px; border-radius: 50%; background: #6c757d; display: inline-block;"></span>
            <span style="color: #6c757d;">Был(а) ${lastSeenText}</span>
        `;
    }
}

// Закрытие по клику на фон
window.addEventListener('click', function(event) {
    if (event.target.classList.contains('popup') || event.target.classList.contains('modal')) {
        event.target.style.display = 'none';
    }

    const userDropdown = document.getElementById('userDropdown');
    const dashboardDropdown = document.getElementById('dashboardDropdown');
    const userAvatar = document.querySelector('.user-avatar');
    const dashboardBtn = document.querySelector('.dashboard-btn');

    if (userDropdown && !userDropdown.contains(event.target) &&
        userAvatar && !userAvatar.contains(event.target)) {
        userDropdown.classList.remove('show');
    }

    if (dashboardDropdown && !dashboardDropdown.contains(event.target) &&
        dashboardBtn && !dashboardBtn.contains(event.target)) {
        dashboardDropdown.classList.remove('show');
    }
});

// Закрытие по ESC
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        document.getElementById('userDropdown')?.classList.remove('show');
        document.getElementById('dashboardDropdown')?.classList.remove('show');
        document.querySelectorAll('.popup, .modal').forEach(el => el.style.display = 'none');
    }
});

// ==================== ЭКСПОРТ ФУНКЦИЙ В ГЛОБАЛЬНУЮ ОБЛАСТЬ ====================
window.showCityPopup = showCityPopup;
window.hideCityPopup = hideCityPopup;
window.showGuidePopup = showGuidePopup;
window.hideGuidePopup = hideGuidePopup;
window.showLoginModal = showLoginModal;
window.hideLoginModal = hideLoginModal;
window.searchCity = searchCity;
window.resetFilters = resetFilters;
window.changeSort = changeSort;
window.setViewMode = setViewMode;
window.showPropertyDetails = showPropertyDetails;
window.hidePropertyModal = hidePropertyModal;
window.showContactForm = showContactForm;
window.showApplicationForm = showApplicationForm;
window.toggleUserMenu = toggleUserMenu;
window.toggleDashboardMenu = toggleDashboardMenu;
window.logout = logout;
window.showMyApplications = showMyApplications;
window.showMyContracts = showMyContracts;
window.showMyProperties = showMyProperties;
window.showAgentStats = showAgentStats;
window.showProfileModal = showProfileModal;
window.showDialogsList = showDialogsList;
window.openModal = openModal;
window.closeModal = closeModal;
window.showAddPropertyModal = showAddPropertyModal;
window.editProperty = editProperty;
window.deleteProperty = deleteProperty;
window.handlePhotoSelect = handlePhotoSelect;
window.removePhoto = removePhoto;
window.updatePhotoPreview = updatePhotoPreview;
window.synchronizeCity = synchronizeCity;
window.uploadAvatar = uploadAvatar;
window.deleteAvatar = deleteAvatar;

// Функции для заявок
window.loadMyApplications = loadMyApplications;
window.showIncomingApplications = showIncomingApplications;
window.showApplicationDetail = showApplicationDetail;
window.cancelApplication = cancelApplication;
window.cancelApplicationFromDetail = cancelApplicationFromDetail;
window.acceptApplication = acceptApplication;
window.rejectApplication = rejectApplication;
window.goToContract = goToContract;
window.closeApplicationDetailAndShowMyApplications = closeApplicationDetailAndShowMyApplications;
window.closeApplicationDetail = closeApplicationDetail;  // Теперь определена

// Функции для чата
window.showDialogsList = showDialogsList;
window.openChat = openChat;
window.closeChat = closeChat;
window.deleteDialog = deleteDialog;
window.contactUser = contactUser;
window.isUserLoggedIn = isUserLoggedIn;
window.initWebSocket = initWebSocket;  // Добавляем для возможности перезапуска

console.log('script.js полностью загружен, все функции экспортированы');

console.log('script.js полностью загружен, все функции экспортированы');