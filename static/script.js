// static/script.js

// Глобальная инициализация
window.hasValidationErrors = false;
window.uploadedFiles = [];

// Убедитесь, что эти переменные объявлены ТОЛЬКО ОДИН РАЗ
let currentViewMode = 'grid';
let currentPropertyId = null;
let existingPhotos = [];
let newPhotos = [];
let deletedPhotoIds = [];
const MAX_PHOTOS = 10;  // <-- ДОЛЖНО БЫТЬ ТОЛЬКО ЗДЕСЬ
let allPhotos = [];      // если используете новый подход

let draggedItem = null;  // для drag & drop

// Глобальная инициализация
window.hasValidationErrors = false;
window.uploadedFiles = [];

console.log('🚀 script.js загружен, версия 2.0');

function formatNotificationText(text) {
    if (!text) return '';
    // Заменяем все **текст** на <strong>текст</strong>
    return text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
}

// Обновление результатов поиска в попапе
function updateCitySearchResults(cities) {
    const container = document.querySelector('.city-search-results');
    if (!container) return;

    if (cities.length === 0) {
        container.innerHTML = '<div class="no-results">Города не найдены</div>';
        return;
    }

    let html = '';
    cities.forEach(city => {
        const match = city.match(/^(.*?)(?:\s*\(([^)]+)\))?$/);
        const cityName = match[1].trim();
        const region = match[2] || '';

        html += `
            <div class="city-result-item" onclick="selectCityFromPopup('${city.replace(/'/g, "\\'")}')">
                <span class="city-name">${cityName}</span>
                ${region ? `<span class="region-name">${region}</span>` : ''}
            </div>
        `;
    });

    container.innerHTML = html;
}

// Выбор города из попапа
function selectCityFromPopup(city) {
    const fullCity = city;
    const cityName = city.split(' (')[0];

    // Обновляем поле в профиле
    const profileCity = document.getElementById('profileCity');
    if (profileCity) {
        profileCity.value = cityName;
        profileCity.dataset.fullCity = fullCity;
    }

    // Обновляем верхнюю панель
    const selectedCity = document.getElementById('selectedCity');
    if (selectedCity) {
        selectedCity.textContent = cityName;
    }

    // Закрываем попап
    hideCityPopup();
}

// Кеш для популярных городов
let popularCities = [];

// Загрузка популярных городов
async function loadPopularCities() {
    try {
        // Получаем популярные города через API
        const cities = await new Promise((resolve) => {
            HH_API.getPopularCities(12, resolve);
        });

        popularCities = cities;
        renderPopularCities();
    } catch (error) {
        console.error('Ошибка загрузки популярных городов:', error);
        // Запасной список
        popularCities = ['Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург',
                        'Казань', 'Нижний Новгород', 'Челябинск', 'Самара'];
        renderPopularCities();
    }
}

// Отображение популярных городов
function renderPopularCities() {
    const grid = document.getElementById('popularCitiesGrid');
    if (!grid) return;

    let html = '';
    popularCities.forEach(city => {
        const cityName = city.split(' (')[0]; // Без региона
        html += `<button class="popular-city-btn" onclick="selectCityFromPopup('${city.replace(/'/g, "\\'")}')">${cityName}</button>`;
    });
    grid.innerHTML = html;
}

// ==================== УПРАВЛЕНИЕ МОДАЛЬНЫМИ ОКНАМИ ====================

function showCityPopup() {
    const popup = document.getElementById('cityPopup');
    popup.style.display = 'flex';

    // Загружаем популярные города при открытии
    loadPopularCities();

    // Очищаем поле поиска
    const searchInput = document.getElementById('citySearch');
    if (searchInput) {
        searchInput.value = '';
        searchInput.focus();
    }

    // Показываем заглушку загрузки
    const resultsContainer = document.getElementById('cityResultsContainer');
    resultsContainer.innerHTML = '<div class="city-loading">Введите минимум 2 символа для поиска</div>';
}


// Обработчик поиска с вежливой паузой
let searchTimeout;
document.getElementById('citySearch')?.addEventListener('input', function() {
    clearTimeout(searchTimeout);

    const query = this.value.trim();
    const resultsContainer = document.getElementById('cityResultsContainer');

    if (query.length < 2) {
        resultsContainer.innerHTML = '<div class="city-loading">Введите минимум 2 символа для поиска</div>';
        return;
    }

    resultsContainer.innerHTML = '<div class="city-loading">Поиск...</div>';

    searchTimeout = setTimeout(() => {
        HH_API.searchCities(query, (cities) => {
            displayCitySearchResults(cities);
        });
    }, 300);
});

// Отображение результатов поиска
function displayCitySearchResults(cities) {
    const container = document.getElementById('cityResultsContainer');

    if (!cities || cities.length === 0) {
        container.innerHTML = '<div class="no-results">Города не найдены</div>';
        return;
    }

    let html = '';
    cities.forEach(city => {
        // Разделяем город и регион
        const match = city.match(/^(.*?)(?:\s*\(([^)]+)\))?$/);
        const cityName = match[1].trim();
        const region = match[2] || '';

        html += `
            <div class="city-result-item" onclick="selectCityFromPopup('${city.replace(/'/g, "\\'")}')">
                <img src="/resources/pin.png" class="pin-icon" alt="📍">
                <span class="city-name">${cityName}</span>
                ${region ? `<span class="region-name">${region}</span>` : ''}
            </div>
        `;
    });

    container.innerHTML = html;
}

// Выбор города из попапа
function selectCityFromPopup(city) {
    const fullCity = city;
    const cityName = city.split(' (')[0]; // Только название города

    // Обновляем поле в профиле, если оно есть
    const profileCity = document.getElementById('profileCity');
    if (profileCity) {
        profileCity.value = cityName;
        profileCity.dataset.fullCity = fullCity;

        // Если есть кастомный селектор, обновляем и его
        if (window.citySelectors && window.citySelectors['profileCity']) {
            window.citySelectors['profileCity'].selectedCity = fullCity;
        }
    }

    // Обновляем поле поиска на главной, если оно есть
    const mainCityInput = document.getElementById('city');
    if (mainCityInput) {
        mainCityInput.value = cityName;
    }

    // Обновляем верхнюю панель
    const selectedCity = document.getElementById('selectedCity');
    if (selectedCity) {
        selectedCity.textContent = cityName;
    }

    // Закрываем попап
    hideCityPopup();

    // Показываем уведомление
    showNotification(`Выбран город: ${cityName}`, 'success');
}

// Скрытие попапа
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

// Получить текущие параметры фильтрации из URL
function getFilterParams() {
    const urlParams = new URLSearchParams(window.location.search);
    return {
        search: urlParams.get('search') || '',
        city: urlParams.get('city') || '',
        property_type: urlParams.get('property_type') || 'all',
        rooms: urlParams.get('rooms') || 'all',
        min_price: urlParams.get('min_price') || '',
        max_price: urlParams.get('max_price') || '',
        min_area: urlParams.get('min_area') || '',
        max_area: urlParams.get('max_area') || '',
        sort_by: urlParams.get('sort_by') || 'newest',
        page: urlParams.get('page') || 1
    };
}

// Обновить URL с параметрами фильтрации
function updateUrlWithFilters() {
    const params = getFilterParams();
    const form = document.getElementById('searchForm');

    // Обновляем значения полей формы из URL
    document.getElementById('search').value = params.search;
    document.getElementById('city').value = params.city;
    document.getElementById('property_type').value = params.property_type;
    document.getElementById('rooms').value = params.rooms;
    document.querySelector('input[name="min_price"]').value = params.min_price;
    document.querySelector('input[name="max_price"]').value = params.max_price;
    document.querySelector('input[name="min_area"]').value = params.min_area;
    document.querySelector('input[name="max_area"]').value = params.max_area;
    document.getElementById('sortByHidden').value = params.sort_by;

    // Устанавливаем выбранную сортировку в select
    const sortSelect = document.getElementById('sortBy');
    if (sortSelect) {
        sortSelect.value = params.sort_by;
    }
}

// Функция изменения сортировки (с сохранением всех фильтров)
function changeSort(sortBy) {
    const url = new URL(window.location.href);
    const params = getFilterParams();

    // Сохраняем все существующие параметры
    if (params.search) url.searchParams.set('search', params.search);
    if (params.city) url.searchParams.set('city', params.city);
    if (params.property_type && params.property_type !== 'all') url.searchParams.set('property_type', params.property_type);
    if (params.rooms && params.rooms !== 'all') url.searchParams.set('rooms', params.rooms);
    if (params.min_price) url.searchParams.set('min_price', params.min_price);
    if (params.max_price) url.searchParams.set('max_price', params.max_price);
    if (params.min_area) url.searchParams.set('min_area', params.min_area);
    if (params.max_area) url.searchParams.set('max_area', params.max_area);

    // Устанавливаем новую сортировку
    url.searchParams.set('sort_by', sortBy);
    url.searchParams.set('page', 1); // Сброс на первую страницу

    window.location.href = url.toString();
}

// Функция изменения страницы (с сохранением всех параметров)
function changePage(newPage) {
    const url = new URL(window.location.href);
    const params = getFilterParams();

    // Сохраняем все существующие параметры
    if (params.search) url.searchParams.set('search', params.search);
    if (params.city) url.searchParams.set('city', params.city);
    if (params.property_type && params.property_type !== 'all') url.searchParams.set('property_type', params.property_type);
    if (params.rooms && params.rooms !== 'all') url.searchParams.set('rooms', params.rooms);
    if (params.min_price) url.searchParams.set('min_price', params.min_price);
    if (params.max_price) url.searchParams.set('max_price', params.max_price);
    if (params.min_area) url.searchParams.set('min_area', params.min_area);
    if (params.max_area) url.searchParams.set('max_area', params.max_area);
    if (params.sort_by) url.searchParams.set('sort_by', params.sort_by);

    // Устанавливаем новую страницу
    url.searchParams.set('page', newPage);

    window.location.href = url.toString();
}

// Функция сброса фильтров (очищает все параметры)
function resetFilters() {
    const url = new URL(window.location.origin + window.location.pathname);
    window.location.href = url.toString();
}

// Функция отправки формы поиска
function submitSearch() {
    const form = document.getElementById('searchForm');
    const formData = new FormData(form);
    const url = new URL(window.location.origin + '/search');

    // Добавляем все параметры формы
    for (let [key, value] of formData.entries()) {
        if (value && value !== 'all' && value !== '') {
            url.searchParams.set(key, value);
        }
    }

    // Добавляем сортировку из select
    const sortSelect = document.getElementById('sortBy');
    if (sortSelect && sortSelect.value !== 'newest') {
        url.searchParams.set('sort_by', sortSelect.value);
    }

    url.searchParams.set('page', 1);
    window.location.href = url.toString();
}

// Восстановление параметров при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    const params = getFilterParams();

    // Восстанавливаем значения полей формы
    const searchInput = document.getElementById('search');
    const cityInput = document.getElementById('city');
    const typeSelect = document.getElementById('property_type');
    const roomsSelect = document.getElementById('rooms');
    const minPriceInput = document.querySelector('input[name="min_price"]');
    const maxPriceInput = document.querySelector('input[name="max_price"]');
    const minAreaInput = document.querySelector('input[name="min_area"]');
    const maxAreaInput = document.querySelector('input[name="max_area"]');
    const sortSelect = document.getElementById('sortBy');

    if (searchInput) searchInput.value = params.search;
    if (cityInput) cityInput.value = params.city;
    if (typeSelect) typeSelect.value = params.property_type;
    if (roomsSelect) roomsSelect.value = params.rooms;
    if (minPriceInput) minPriceInput.value = params.min_price;
    if (maxPriceInput) maxPriceInput.value = params.max_price;
    if (minAreaInput) minAreaInput.value = params.min_area;
    if (maxAreaInput) maxAreaInput.value = params.max_area;
    if (sortSelect) sortSelect.value = params.sort_by;

    // Применяем сортировку к карточкам на странице (если нужно)
    if (params.sort_by !== 'newest') {
        changeSort(params.sort_by);
    }

    // Обработчик отправки формы
    const searchForm = document.getElementById('searchForm');
    if (searchForm) {
        searchForm.addEventListener('submit', function(e) {
            e.preventDefault();
            submitSearch();
        });
    }
});

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
    const cards = document.querySelectorAll('.property-card');

    if (mode === 'grid') {
        container.className = 'results-grid';
        gridBtn.classList.add('active');
        listBtn.classList.remove('active');

        // Скрываем описание в режиме сетки
        cards.forEach(card => {
            const desc = card.querySelector('.property-description');
            if (desc) desc.style.display = 'none';
        });
    } else {
        container.className = 'results-list';
        gridBtn.classList.remove('active');
        listBtn.classList.add('active');

        // Показываем описание в режиме списка
        cards.forEach(card => {
            const desc = card.querySelector('.property-description');
            if (desc) desc.style.display = 'block';
        });
    }

    currentViewMode = mode;
}

function changePage(newPage) {
    const form = document.getElementById('searchForm');
    const pageInput = document.getElementById('pageInput');
    if (pageInput) {
        pageInput.value = newPage;
    } else {
        // Если нет скрытого поля (на главной), создадим временную форму
        const url = new URL(window.location.href);
        url.searchParams.set('page', newPage);
        window.location.href = url.toString();
        return;
    }
    form.submit();
}



function updateModalGallery(photos) {
    console.log('updateModalGallery вызвана с фото:', photos);
    const mainImage = document.getElementById('modalMainImageImg');
    const thumbnailContainer = document.getElementById('modalThumbnailContainer');

    if (photos && photos.length > 0) {
        mainImage.src = photos[0].url || '/resources/placeholder-image.png';

        thumbnailContainer.innerHTML = '';
        photos.forEach((photo, index) => {
            const thumb = document.createElement('div');
            thumb.className = `modal-thumbnail ${index === 0 ? 'active' : ''}`;
            thumb.onclick = () => changeModalImage(photo.url, thumb);
            thumb.innerHTML = `<img src="${photo.url}" alt="Thumbnail ${index + 1}">`;
            thumbnailContainer.appendChild(thumb);
        });
    } else {
        mainImage.src = '/resources/placeholder-image.png';
        thumbnailContainer.innerHTML = '';
    }
}

// ==================== ПОЛНОЭКРАННАЯ ГАЛЕРЕЯ ====================
let currentGalleryIndex = 0;
let galleryPhotos = [];

function openFullscreenGallery() {
    if (galleryPhotos.length === 0) return;
    currentGalleryIndex = 0;
    updateFullscreenImage();
    document.getElementById('fullscreenGalleryModal').style.display = 'flex';
}

function closeFullscreenGallery() {
    document.getElementById('fullscreenGalleryModal').style.display = 'none';
}

function nextGalleryImage() {
    if (galleryPhotos.length > 0) {
        currentGalleryIndex = (currentGalleryIndex + 1) % galleryPhotos.length;
        updateFullscreenImage();
    }
}

function prevGalleryImage() {
    if (galleryPhotos.length > 0) {
        currentGalleryIndex = (currentGalleryIndex - 1 + galleryPhotos.length) % galleryPhotos.length;
        updateFullscreenImage();
    }
}

function updateFullscreenImage() {
    if (galleryPhotos.length > 0) {
        document.getElementById('fullscreenImage').src = galleryPhotos[currentGalleryIndex].url;
        document.getElementById('galleryCounter').textContent = `${currentGalleryIndex + 1} / ${galleryPhotos.length}`;
    }
}

// Обновляем updateModalGallery для сохранения фотографий
const originalUpdateModalGallery = updateModalGallery;
updateModalGallery = function(photos) {
    originalUpdateModalGallery(photos);
    galleryPhotos = photos;
};

function changeModalImage(imageUrl, thumbnail) {
    document.getElementById('modalMainImageImg').src = imageUrl;
    document.querySelectorAll('.modal-thumbnail').forEach(thumb => {
        thumb.classList.remove('active');
    });
    thumbnail.classList.add('active');
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

    // Скрываем статус (он больше не нужен)
    // const statusBadge = document.getElementById('modalPropertyStatus');
    // statusBadge.textContent = data.status === 'active' ? 'Активно' :
    //     data.status === 'rented' ? 'Сдано' : 'В архиве';
    // statusBadge.className = `property-status-badge status-${data.status || 'active'}`;

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

    // Загружаем ответственное лицо
    fetch(`/api/property/${data.property_id}/responsible`, { credentials: 'same-origin' })
        .then(res => res.json())
        .then(responsible => {
            document.getElementById('modalResponsibleName').textContent = responsible.name || 'Не указан';
            document.getElementById('modalResponsibleEmail').textContent = responsible.email || '-';
            document.getElementById('modalResponsiblePhone').textContent = responsible.phone || '-';
        })
        .catch(err => console.error('Ошибка загрузки ответственной стороны:', err));

    // Управление кнопками администратора
    const adminHeaderActions = document.getElementById('adminHeaderActions');
    if (window.currentUser && window.currentUser.type === 'admin') {
        adminHeaderActions.style.display = 'flex';
        document.getElementById('regularUserActions').style.display = 'flex';
    } else {
        adminHeaderActions.style.display = 'none';
        document.getElementById('regularUserActions').style.display = 'flex';
    }
}

// Новая функция для перепубликации объекта
async function republishProperty(propertyId) {
    if (!confirm('Хотите сделать этот объект снова доступным для аренды?')) return;

    try {
        const response = await fetch(`/api/properties/${propertyId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: 'active' }),
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка перепубликации');
        }

        showNotification('Объект снова доступен для аренды', 'success');

        // Обновляем отображение
        if (currentPropertyId === propertyId) {
            showPropertyDetails(propertyId);
        }

        // Обновляем список объектов если открыт
        if (document.getElementById('myPropertiesModal').style.display === 'flex') {
            loadMyProperties();
        }

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

function showContactForm() {
    if (!isUserLoggedIn()) {
        showNotification('Необходимо авторизоваться', 'warning');
        showLoginModal();
        return;
    }

    if (!currentPropertyId) {
        showNotification('Ошибка: не указан объект', 'error');
        return;
    }

    // Получаем информацию об ответственной стороне
    fetch(`/api/property/${currentPropertyId}/responsible`, { credentials: 'same-origin' })
        .then(response => {
            if (!response.ok) throw new Error('Не удалось определить получателя');
            return response.json();
        })
        .then(responsible => {
            openChat(responsible.id);
        })
        .catch(error => {
            console.error('Ошибка:', error);
            showNotification('Не удалось определить получателя', 'error');
        });
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

async function reportProperty(propertyId) {
    if (!confirm('Отправить жалобу на этот объект модераторам?')) return;

    try {
        // Здесь должен быть эндпоинт для отправки жалобы
        // Если его нет, можно просто показать уведомление
        showNotification('Жалоба отправлена. Спасибо за помощь!', 'success');

        // Или если есть эндпоинт:
        // const response = await fetch(`/api/properties/${propertyId}/report`, {
        //     method: 'POST',
        //     credentials: 'same-origin'
        // });
        // if (!response.ok) throw new Error('Ошибка отправки жалобы');
        // showNotification('Жалоба отправлена', 'success');

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка при отправке жалобы', 'error');
    }
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

// ==================== ОТЧЕТНОСТЬ =====================
async function downloadContract() {
    const contractId = document.getElementById('contractDetailModal').dataset.contractId;
    if (!contractId) {
        showNotification('Ошибка: не указан договор', 'error');
        return;
    }

    try {
        showNotification('Генерация договора...', 'info');

        const response = await fetch(`/api/contracts/${contractId}/generate-contract?format=docx`, {
            method: 'POST',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка генерации');
        }

        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `contract_${contractId}.docx`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);

        showNotification('Договор успешно сгенерирован', 'success');

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

async function downloadAct() {
    const contractId = document.getElementById('contractDetailModal').dataset.contractId;
    if (!contractId) {
        showNotification('Ошибка: не указан договор', 'error');
        return;
    }

    try {
        showNotification('Генерация акта...', 'info');

        const response = await fetch(`/api/contracts/${contractId}/generate-act?format=pdf`, {
            method: 'POST',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка генерации');
        }

        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `act_${contractId}.pdf`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);

        showNotification('Акт успешно сгенерирован', 'success');

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

async function exportAgentStats() {
    const period = document.getElementById('statsPeriod').value;

    try {
        showNotification('Генерация отчета...', 'info');

        const response = await fetch(`/api/agent/export-stats?months=${period}`, {
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка экспорта');
        }

        // Получаем blob из ответа
        const blob = await response.blob();

        // Создаем ссылку для скачивания
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `agent_stats_${period}months.xlsx`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);

        showNotification('Отчет успешно скачан', 'success');

    } catch (error) {
        console.error('Ошибка экспорта:', error);
        showNotification(error.message, 'error');
    }
}

// ==================== ФУНКЦИИ ДЛЯ МОДАЛЬНЫХ ОКОН ====================

function showMyApplications() {
    console.log('showMyApplications вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadMyApplications(); // Загружаем свежие данные
    openModal('myApplicationsModal');
}
async function showContractDetail(contractId, source = 'contracts') {
    try {
        const response = await fetch(`/api/contracts/${contractId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки договора');

        const contract = await response.json();
        console.log('Детали договора:', contract);

        // Сохраняем ID и источник в dataset
        const modal = document.getElementById('contractDetailModal');
        modal.dataset.contractId = contractId;
        modal.dataset.source = source;

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

        // Статус договора
        const statusConfig = {
            'draft': { bg: '#e9ecef', color: '#6c757d', text: '📄 Черновик' },
            'pending': { bg: '#fff3cd', color: '#856404', text: '⏳ Ожидает подписи' },
            'signed': { bg: '#d4edda', color: '#155724', text: '✅ Подписан' },
            'cancelled': { bg: '#f8d7da', color: '#721c24', text: '🚫 Отменён' }
        };
        const status = statusConfig[contract.signing_status] || { bg: '#e9ecef', color: '#6c757d', text: contract.signing_status };
        document.getElementById('contractDetailStatus').innerHTML = `<span style="padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${status.bg}; color: ${status.color};">${status.text}</span>`;

        // Информация о сторонах
        document.getElementById('contractDetailTenantName').textContent = contract.tenant_name || 'Не указан';
        document.getElementById('contractDetailTenantEmail').textContent = contract.tenant_email || '';
        document.getElementById('contractDetailOwnerName').textContent = contract.owner_name || 'Не указан';
        document.getElementById('contractDetailOwnerEmail').textContent = contract.owner_email || '';

        // ===== ОТОБРАЖЕНИЕ ПОДПИСЕЙ =====
        const tenantSignEl = document.getElementById('contractDetailTenantSign');
        const ownerSignEl = document.getElementById('contractDetailOwnerSign');

        // Подпись арендатора
        if (contract.tenant_signed) {
            tenantSignEl.innerHTML = `
                <div style="display: flex; align-items: center; gap: 8px;">
                    <span style="color: #28a745; font-size: 18px;">✓</span>
                    <span style="color: #28a745; font-weight: 500;">Подписано</span>
                </div>
            `;
        } else {
            tenantSignEl.innerHTML = `
                <div style="display: flex; align-items: center; gap: 8px;">
                    <span style="color: #ffc107; font-size: 18px;">⏳</span>
                    <span style="color: #6c757d;">Ожидает подписания</span>
                </div>
            `;
        }

        // Подпись собственника
        if (contract.owner_signed) {
            ownerSignEl.innerHTML = `
                <div style="display: flex; align-items: center; gap: 8px;">
                    <span style="color: #28a745; font-size: 18px;">✓</span>
                    <span style="color: #28a745; font-weight: 500;">Подписано</span>
                </div>
            `;
        } else {
            ownerSignEl.innerHTML = `
                <div style="display: flex; align-items: center; gap: 8px;">
                    <span style="color: #ffc107; font-size: 18px;">⏳</span>
                    <span style="color: #6c757d;">Ожидает подписания</span>
                </div>
            `;
        }

        // ===== ЛОГИКА ОТОБРАЖЕНИЯ КНОПОК =====
        const currentUser = window.currentUser;
        const isOwner = currentUser && (currentUser.type === 'owner' || currentUser.type === 'agent');

        const signButton = document.getElementById('contractSignButton');
        const cancelBtn = document.getElementById('cancelContractBtn');
        const downloadContractBtn = document.getElementById('downloadContractBtn');
        const downloadActBtn = document.getElementById('downloadActBtn');

        // Сбрасываем видимость всех кнопок
        if (signButton) signButton.style.display = 'none';
        if (cancelBtn) cancelBtn.style.display = 'none';
        if (downloadContractBtn) downloadContractBtn.style.display = 'none';
        if (downloadActBtn) downloadActBtn.style.display = 'none';

        if (contract.signing_status === 'cancelled') {
            // Договор отменён - ничего не показываем
            // Кнопки уже скрыты
        } else if (contract.signing_status === 'signed') {
            // Договор полностью подписан - показываем кнопки скачивания и отмены
            if (cancelBtn) cancelBtn.style.display = 'block';
            if (downloadContractBtn) downloadContractBtn.style.display = 'block';
            if (downloadActBtn) downloadActBtn.style.display = 'block';
        } else {
            // Договор ещё не подписан полностью
            let canSign = false;

            if (currentUser && currentUser.type === 'tenant' && !contract.tenant_signed) {
                canSign = true;
            }
            if (isOwner && !contract.owner_signed) {
                canSign = true;
            }

            if (canSign && signButton) {
                signButton.style.display = 'block';
            }

            if (isOwner && cancelBtn) {
                cancelBtn.style.display = 'block';
            }
        }

        // Закрываем предыдущие модальные окна и открываем детали договора
        closeModal('myContractsModal');
        closeModal('incomingContractsModal');
        openModal('contractDetailModal');

    } catch (error) {
        console.error('Ошибка загрузки деталей договора:', error);
        showNotification('Ошибка загрузки деталей договора', 'error');
    }
}
// ==================== ДОГОВОРЫ ====================
// Общая функция загрузки договоров
async function loadContracts(containerId, myOnly) {
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

        const container = document.getElementById(containerId);
        if (!container) return;

        // Фильтруем договоры
        let filteredContracts = contracts;
        if (myOnly) {
            filteredContracts = contracts.filter(c => c.is_tenant);
        } else {
            filteredContracts = contracts.filter(c => c.is_owner);
        }

        if (filteredContracts.length === 0) {
            container.innerHTML = '<p style="text-align: center; padding: 40px; color: #6c757d;">Нет договоров</p>';
            return;
        }

        let html = '';
        filteredContracts.forEach(contract => {
            const statusConfig = {
                'draft': { bg: '#e9ecef', color: '#6c757d', text: '📄 Черновик' },
                'pending': { bg: '#fff3cd', color: '#856404', text: '⏳ Ожидает подписи' },
                'signed': { bg: '#d4edda', color: '#155724', text: '✅ Подписан' },
                'cancelled': { bg: '#f8d7da', color: '#721c24', text: '🚫 Отменён' }
            };
            const status = statusConfig[contract.signing_status] || { bg: '#e9ecef', color: '#6c757d', text: contract.signing_status };

            const startDate = contract.start_date ? new Date(contract.start_date).toLocaleDateString('ru-RU') : '?';
            const endDate = contract.end_date ? new Date(contract.end_date).toLocaleDateString('ru-RU') : '?';
            const amount = contract.total_amount ? Number(contract.total_amount).toLocaleString('ru-RU') : '0';

            // Статус подписания сторон
            let signedStatus = '';
            if (contract.signing_status === 'signed') {
                signedStatus = '✓ Подписан обеими сторонами';
            } else if (contract.tenant_signed && !contract.owner_signed) {
                signedStatus = '⏳ Арендатор подписал, ожидает собственника';
            } else if (!contract.tenant_signed && contract.owner_signed) {
                signedStatus = '⏳ Собственник подписал, ожидает арендатора';
            } else {
                signedStatus = '⏳ Ожидает подписания';
            }

            html += `
                <div class="contract-item" onclick="showContractDetail(${contract.contract_id}, 'contracts')" style="display: flex; gap: 15px; padding: 15px; border-bottom: 1px solid #e9ecef; cursor: pointer; align-items: center;">
                    <div style="width: 80px; height: 80px; flex-shrink: 0;">
                        <img src="${contract.property_photo}" style="width: 100%; height: 100%; object-fit: cover; border-radius: 8px;" onerror="this.src='/resources/placeholder-image.png'">
                    </div>
                    <div style="flex: 1;">
                        <div style="font-weight: 700; font-size: 16px;">${contract.contract_number}</div>
                        <div style="color: #212529;">${contract.property_title || 'Без названия'}</div>
                        <div style="color: #6c757d; font-size: 14px;">Период: ${startDate} - ${endDate}</div>
                        <div style="font-size: 13px; color: #495057; margin-top: 4px;">${signedStatus}</div>
                    </div>
                    <div style="text-align: right;">
                        <div style="margin-bottom: 8px;">
                            <span style="padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${status.bg}; color: ${status.color};">${status.text}</span>
                        </div>
                        <div style="font-weight: 700; color: #28a745; font-size: 16px;">${amount} ₽</div>
                    </div>
                </div>
            `;
        });
        container.innerHTML = html;

    } catch (error) {
        console.error('Ошибка загрузки договоров:', error);
        showNotification('Ошибка загрузки договоров', 'error');
    }
}

// Показать мои договоры
function showMyContracts() {
    console.log('showMyContracts вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadContracts('myContractsList', true); // true - мои договоры (где я арендатор)
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



// Закрыть детали и вернуться к списку
function closeContractDetailAndShowList() {
    const modal = document.getElementById('contractDetailModal');
    const source = modal.dataset.source || 'contracts';

    closeModal('contractDetailModal');

    if (source === 'incoming-applications') {
        showIncomingApplications(); // Возвращаемся к входящим заявкам
    } else {
        // По умолчанию возвращаемся к соответствующему списку договоров
        const currentUser = window.currentUser;
        if (currentUser && (currentUser.type === 'owner' || currentUser.type === 'agent')) {
            showIncomingContracts(); // Для собственника/агента - входящие договоры
        } else {
            showMyContracts(); // Для арендатора - мои договоры
        }
    }
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
        await showContractDetail(contractId);

        // Обновляем списки договоров, если они открыты
        if (document.getElementById('myContractsModal').style.display === 'flex') {
            loadContracts('myContractsList', true);
        }
        if (document.getElementById('incomingContractsModal').style.display === 'flex') {
            loadContracts('incomingContractsList', false);
        }

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

function showIncomingApplications() {
    console.log('showIncomingApplications вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadIncomingApplications();
    openModal('incomingApplicationsModal');
}

async function loadIncomingApplications() {
    try {
        const response = await fetch('/api/incoming/applications', { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки');

        const applications = await response.json();
        console.log('Входящие заявки:', applications);

        const container = document.getElementById('incomingApplicationsList');
        if (!container) return;

        const pendingApps = applications.filter(app => app.status === 'pending');

        if (pendingApps.length === 0) {
            container.innerHTML = '<p style="text-align: center; padding: 40px; color: #6c757d;">Нет входящих заявок</p>';
            return;
        }

        let html = '';
        pendingApps.forEach(app => {
            const desiredDate = app.desired_date ? new Date(app.desired_date).toLocaleDateString('ru-RU') : 'не указана';

            html += `
                <div class="application-card" onclick="showRespondModal(${app.application_id})"
                     style="display: flex; gap: 15px; padding: 15px; border-bottom: 1px solid #e9ecef; cursor: pointer;">
                    <img src="${app.property_photo || '/resources/placeholder-image.png'}"
                         style="width: 80px; height: 80px; object-fit: cover; border-radius: 8px;">
                    <div style="flex: 1;">
                        <div style="font-weight: 600; font-size: 16px; margin-bottom: 4px;">${app.property_title || 'Без названия'}</div>
                        <div style="color: #6c757d; font-size: 13px; margin-bottom: 6px;">${app.property_address || ''}</div>
                        <div style="display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 6px; font-size: 13px;">
                            <span style="background: #e9ecef; padding: 2px 8px; border-radius: 12px;">
                                👤 ${app.tenant_name || 'Неизвестно'}
                            </span>
                            <span style="background: #e9ecef; padding: 2px 8px; border-radius: 12px;">
                                📅 ${desiredDate}
                            </span>
                            <span style="background: #e9ecef; padding: 2px 8px; border-radius: 12px;">
                                ⏱ ${app.duration_days || '?'} дн.
                            </span>
                        </div>
                        <div style="font-size: 13px; color: #495057; background: #f8f9fa; padding: 6px; border-radius: 6px; margin-top: 4px;">
                            💬 ${app.message || 'Нет сообщения'}
                        </div>
                    </div>
                    <div style="display: flex; flex-direction: column; justify-content: center; gap: 8px;">
                        <span style="background: #fff3cd; color: #856404; padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 500; text-align: center;">
                            Требует ответа
                        </span>
                        <button class="btn-primary" onclick="event.stopPropagation(); showRespondModal(${app.application_id})"
                                style="padding: 8px 16px; font-size: 13px; background: #007bff; color: white; border: none; border-radius: 6px; cursor: pointer;">
                            Ответить
                        </button>
                    </div>
                </div>
            `;
        });
        container.innerHTML = html;
    } catch (error) {
        console.error('Ошибка загрузки входящих заявок:', error);
        showNotification('Ошибка загрузки входящих заявок', 'error');
    }
}


// Заглушки для остальных функций
async function cancelContract() {
    if (!confirm('Вы уверены, что хотите отменить договор? Это действие нельзя отменить.')) return;

    const contractId = document.getElementById('contractDetailModal').dataset.contractId;
    if (!contractId) {
        showNotification('Ошибка: не указан договор', 'error');
        return;
    }

    try {
        const response = await fetch(`/api/contracts/${contractId}/cancel`, {
            method: 'POST',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка отмены договора');
        }

        showNotification('Договор отменён', 'success');

        // Закрываем модальное окно
        closeModal('contractDetailModal');

        // Обновляем списки
        if (document.getElementById('myContractsModal').style.display === 'flex') {
            loadContracts('myContractsList', true);
        }
        if (document.getElementById('incomingContractsModal').style.display === 'flex') {
            loadContracts('incomingContractsList', false);
        }

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

async function loadAgentStats() {
    const period = document.getElementById('statsPeriod').value;

    // Преобразуем месяцы в дни для круговой диаграммы
    let days = 90; // по умолчанию 3 месяца
    if (period === '6') days = 180;
    if (period === '12') days = 365;

    try {
        // Загружаем месячные данные
        const monthlyRes = await fetch(`/api/agent/stats?months=${period}`, { credentials: 'same-origin' });
        if (!monthlyRes.ok) throw new Error('Ошибка загрузки месячной статистики');
        const monthlyData = await monthlyRes.json();
        console.log('Monthly data:', monthlyData);

        // Загружаем KPI
        const perfRes = await fetch(`/api/agent/performance?months=${period}`, { credentials: 'same-origin' });
        if (!perfRes.ok) throw new Error('Ошибка загрузки KPI');
        const perfData = await perfRes.json();
        console.log('Performance data:', perfData);

        // Загружаем статусы
        const statusRes = await fetch(`/api/agent/rejection-reasons?days=${days}`, { credentials: 'same-origin' });
        if (!statusRes.ok) throw new Error('Ошибка загрузки статусов');
        const statusData = await statusRes.json();
        console.log('Status data for', days, 'days:', statusData);

        // Обновляем KPI
        document.getElementById('statsTotalProfit').textContent = perfData.total_profit
            ? Number(perfData.total_profit).toLocaleString('ru-RU', { maximumFractionDigits: 0 }) + ' ₽'
            : '0 ₽';

        document.getElementById('statsAvgProfit').textContent = perfData.avg_profit_per_property
            ? Number(perfData.avg_profit_per_property).toLocaleString('ru-RU', { maximumFractionDigits: 0 }) + ' ₽'
            : '0 ₽';

        document.getElementById('statsTotalDeals').textContent = perfData.total_deals || 0;

        document.getElementById('statsOccupancy').textContent = perfData.occupancy_rate
            ? Number(perfData.occupancy_rate).toFixed(1) + '%'
            : '0%';

        document.getElementById('statsProcessedApps').textContent = perfData.processed_applications || 0;

        const avgHours = perfData.avg_response_hours || 0;
        document.getElementById('statsAvgResponseTime').textContent = avgHours.toFixed(2) + ' ч';

        const conversion = perfData.conversion_rate || 0;
        document.getElementById('statsConversionRate').textContent = conversion.toFixed(2) + '%';

        // ===== СТОЛБЧАТАЯ ДИАГРАММА =====
        const ctx1 = document.getElementById('dealsChart')?.getContext('2d');
        if (ctx1) {
            if (window.dealsChart && typeof window.dealsChart.destroy === 'function') {
                window.dealsChart.destroy();
            }

            if (!monthlyData || monthlyData.length === 0) {
                document.getElementById('dealsChartContainer').innerHTML =
                    '<p style="text-align: center; color: #6c757d; padding: 20px;">Нет данных за выбранный период</p>';
            } else {
                // Сортируем данные по месяцам (от старых к новым)
                const sortedMonthlyData = [...monthlyData].sort((a, b) => {
                    if (a.month < b.month) return -1;
                    if (a.month > b.month) return 1;
                    return 0;
                });

                const labels = sortedMonthlyData.map(d => {
                    const [year, month] = d.month.split('-');
                    const monthNames = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
                                      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
                    return `${monthNames[parseInt(month)-1]} ${year}`;
                });

                window.dealsChart = new Chart(ctx1, {
                    type: 'bar',
                    data: {
                        labels: labels,
                        datasets: [
                            {
                                label: 'Прибыль (₽)',
                                data: sortedMonthlyData.map(d => d.total_profit || 0),
                                backgroundColor: 'rgba(40, 167, 69, 0.7)',
                                borderColor: '#28a745',
                                borderWidth: 1,
                                yAxisID: 'y'
                            },
                            {
                                label: 'Сделки',
                                data: sortedMonthlyData.map(d => d.deals_count || 0),
                                backgroundColor: 'rgba(0, 123, 255, 0.7)',
                                borderColor: '#007bff',
                                borderWidth: 1,
                                yAxisID: 'y1'
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: {
                            y: {
                                type: 'linear',
                                display: true,
                                position: 'left',
                                beginAtZero: true,
                                title: { display: true, text: 'Прибыль (₽)' }
                            },
                            y1: {
                                type: 'linear',
                                display: true,
                                position: 'right',
                                beginAtZero: true,
                                title: { display: true, text: 'Количество сделок' },
                                grid: { drawOnChartArea: false },
                                ticks: { stepSize: 1, precision: 0 }
                            }
                        }
                    }
                });
            }
        }

        // ===== КРУГОВАЯ ДИАГРАММА =====
        const ctx2 = document.getElementById('pieChart')?.getContext('2d');
        if (ctx2) {
            if (window.pieChart && typeof window.pieChart.destroy === 'function') {
                window.pieChart.destroy();
            }

            if (!statusData || statusData.length === 0) {
                document.getElementById('pieChartContainer').innerHTML =
                    '<p style="text-align: center; color: #6c757d; padding: 20px;">Нет данных за выбранный период</p>';
                return;
            }

            // Фильтруем только нужные статусы
            const filteredData = statusData.filter(item =>
                item.status === 'approved' || item.status === 'rejected'
            );

            if (filteredData.length === 0) {
                document.getElementById('pieChartContainer').innerHTML =
                    '<p style="text-align: center; color: #6c757d; padding: 20px;">Нет данных для отображения</p>';
                return;
            }

            const labels = [];
            const data = [];
            const colors = ['#28a745', '#dc3545'];

            filteredData.forEach((item, index) => {
                const statusNames = {
                    'approved': '✅ Одобрено',
                    'rejected': '❌ Отказано'
                };
                labels.push(statusNames[item.status] || item.status);
                data.push(item.count || 0);
            });

            const total = data.reduce((a, b) => a + b, 0);

            window.pieChart = new Chart(ctx2, {
                type: 'pie',
                data: {
                    labels: labels,
                    datasets: [{
                        data: data,
                        backgroundColor: colors.slice(0, data.length),
                        borderColor: 'white',
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { position: 'bottom' },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    const label = context.label || '';
                                    const value = context.raw || 0;
                                    const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                                    return `${label}: ${value} (${percentage}%)`;
                                }
                            }
                        }
                    }
                }
            });
        }

    } catch (error) {
        console.error('Ошибка загрузки статистики:', error);
        showNotification('Ошибка загрузки статистики', 'error');
    }
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
function showIncomingContracts() {
    console.log('showIncomingContracts вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadContracts('incomingContractsList', false); // false - входящие (где я собственник)
    openModal('incomingContractsModal');
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
        document.getElementById('detailPrice').style.color = '#28a745';

        // ===== УПРАВЛЕНИЕ КНОПКОЙ ОТМЕНЫ =====
        const cancelButton = document.querySelector('#applicationDetailModal .btn-danger');
        if (cancelButton) {
            // Показываем кнопку отмены ТОЛЬКО для статуса 'pending'
            if (app.status === 'pending') {
                cancelButton.style.display = 'block';
            } else {
                cancelButton.style.display = 'none';
            }
        }

        closeModal('myApplicationsModal');
        openModal('applicationDetailModal');
    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка загрузки деталей заявки', 'error');
    }
}

// Функция для отправки формы с указанием статуса
async function submitPropertyForm(status) {

    const form = document.getElementById('propertyEditForm');
    const isEditing = !!form.dataset.propertyId;

    const propertyId = form.dataset.propertyId;
    const url = isEditing ? `/api/properties/${propertyId}` : `/api/properties`;

    document.getElementById('propStatus').value = status;

    const formData = new FormData();

    // ===== ПОЛЯ ФОРМЫ =====

    formData.append('status', status);
    formData.append('title', document.getElementById('propTitle')?.value.trim() || '');
    formData.append('description', document.getElementById('propDescription')?.value.trim() || '');
    formData.append('address', document.getElementById('propAddress')?.value.trim() || '');
    formData.append('city', document.getElementById('propCity')?.value.trim() || '');
    formData.append('property_type', document.getElementById('propType')?.value || 'apartment');
    formData.append('area', document.getElementById('propArea')?.value || '0');
    formData.append('rooms', document.getElementById('propRooms')?.value || '0');
    formData.append('price', document.getElementById('propPrice')?.value || '0');
    formData.append('interval_pay', document.getElementById('propInterval')?.value || 'month');

    // ===== ПРОВЕРКА ОБЯЗАТЕЛЬНЫХ ПОЛЕЙ =====

    const requiredFields = ['title', 'address', 'city', 'property_type', 'area', 'price', 'interval_pay'];

    for (let field of requiredFields) {

        if (!formData.get(field)) {

            showNotification(`Заполните поле ${field}`, 'error');
            return;

        }

    }

    // ===== ОБРАБОТКА ФОТО =====

    const photoOrder = [];
    const newPhotoTmpIds = [];
    const numericDeletedIds = [];

    const newPhotoFiles = [];

    allPhotos.forEach(photo => {

        if (!photo.isNew) {

            photoOrder.push({
                id: Number(photo.id),
                type: "existing"
            });

        } else {

            photoOrder.push({
                id: photo.id,
                type: "new"
            });

            newPhotoTmpIds.push(photo.id);

            if (photo.file) {
                newPhotoFiles.push(photo.file);
            }

        }

    });

    deletedPhotoIds.forEach(id => {
        numericDeletedIds.push(Number(id));
    });

    // добавляем файлы ПОСЛЕ формирования массива
    newPhotoFiles.forEach(file => {
        formData.append("photos", file);
    });

    formData.append("photo_order", JSON.stringify(photoOrder));
    formData.append("new_photo_tmp_ids", JSON.stringify(newPhotoTmpIds));
    formData.append("deleted_photos", JSON.stringify(numericDeletedIds));

    console.log('📤 Отправляемые данные:');
    console.log('photo_order:', photoOrder);
    console.log('new_photo_tmp_ids:', newPhotoTmpIds);
    console.log('deleted_photos:', numericDeletedIds);
    console.log('Всего фото:', allPhotos.length);

    // ===== БЛОКИРУЕМ КНОПКИ =====

    const submitButtons = document.querySelectorAll(
        '#propertyEditForm .btn-primary, #propertyEditForm .btn-warning'
    );

    submitButtons.forEach(btn => btn.disabled = true);

    try {

        const response = await fetch(url, {
            method: isEditing ? 'PUT' : 'POST',
            body: formData,
            credentials: 'same-origin'
        });

        const text = await response.text();

        console.log('📥 Ответ сервера:', text);

        if (!response.ok) {

            let errorMsg = 'Ошибка сохранения';

            try {

                const err = JSON.parse(text);
                errorMsg = err.detail || err.message || JSON.stringify(err);

            } catch {

                errorMsg = text || errorMsg;

            }

            throw new Error(errorMsg);

        }

        const result = JSON.parse(text);

        showNotification(
            isEditing ? '✅ Объект обновлён' : '✅ Объект создан',
            'success'
        );

        // ===== ОЧИСТКА ФОРМЫ =====

        form.reset();
        delete form.dataset.propertyId;

        // освобождаем blob URL

        allPhotos.forEach(photo => {

            if (photo.isNew && photo.url && photo.url.startsWith('blob:')) {

                URL.revokeObjectURL(photo.url);

            }

        });

        // сбрасываем переменные

        allPhotos = [];
        deletedPhotoIds = [];

        if (typeof renderPhotos === 'function') {
            renderPhotos();
        }

        closeModal('propertyEditModal');

        if (document.getElementById('myPropertiesModal')?.style.display === 'flex') {
            loadMyProperties();
        }

    }

    catch (error) {

        console.error('❌ Ошибка:', error);
        showNotification(error.message, 'error');

    }

    finally {

        submitButtons.forEach(btn => btn.disabled = false);

    }

}

// Функция для отмены заявки
async function cancelApplication(applicationId) {
    // Сначала проверим статус заявки
    try {
        const response = await fetch(`/api/applications/${applicationId}`, { credentials: 'same-origin' });
        if (response.ok) {
            const app = await response.json();
            if (app.status !== 'pending') {
                showNotification(`Нельзя отменить заявку со статусом "${app.status}"`, 'error');
                loadMyApplications(); // Обновляем список
                return;
            }
        }
    } catch (error) {
        console.error('Ошибка проверки статуса:', error);
    }

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

function closeApplicationDetail() {
    closeModal('applicationDetailModal');
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

function goToContractFromApplication(contractId) {
    if (contractId) {
        showContractDetail(contractId, 'incoming-applications');
    } else {
        showNotification('Договор ещё не создан', 'info');
    }
}

// Функция для открытия модального окна ответа на заявку
async function showRespondModal(applicationId) {
    try {
        const response = await fetch(`/api/applications/${applicationId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки данных заявки');

        const app = await response.json();
        console.log('Данные заявки для ответа:', app);

        // Заполняем информацию о заявке
        document.getElementById('respondApplicationId').value = app.application_id;
        document.getElementById('respondPropertyTitle').textContent = app.property_title || 'Название объекта';
        document.getElementById('respondPropertyAddress').textContent = app.property_address || 'Адрес не указан';

        // Фото
        if (app.property_photo) {
            document.getElementById('respondPropertyImage').src = app.property_photo;
        }

        // Информация об арендаторе
        document.getElementById('respondTenantName').textContent = app.tenant_name || 'Неизвестно';

        // Даты
        const desiredDate = app.desired_date ? new Date(app.desired_date).toLocaleDateString('ru-RU') : 'не указана';
        document.getElementById('respondDesiredDate').textContent = desiredDate;
        document.getElementById('respondDuration').textContent = app.duration_days || '?';
        document.getElementById('respondMessage').textContent = app.message || '-';

        // Устанавливаем минимальную дату для новой даты заселения - сегодня
        const today = new Date().toISOString().split('T')[0];
        const newDateInput = document.getElementById('respondNewDesiredDate');
        if (newDateInput) {
            newDateInput.min = today;
            newDateInput.value = '';
        }

        // Очищаем поля
        const durationInput = document.getElementById('respondDurationDays');
        if (durationInput) durationInput.value = '';

        const answerInput = document.getElementById('respondAnswer');
        if (answerInput) answerInput.value = '';

        // Устанавливаем радио-кнопку "Одобрить" по умолчанию
        const approvedRadio = document.querySelector('input[name="status"][value="approved"]');
        if (approvedRadio) approvedRadio.checked = true;

        openModal('respondApplicationModal');

    } catch (error) {
        console.error('Ошибка загрузки заявки:', error);
        showNotification('Ошибка загрузки данных заявки', 'error');
    }
}

// Обработчик отправки формы ответа
document.addEventListener('DOMContentLoaded', function() {
    const respondForm = document.getElementById('respondApplicationForm');
    if (respondForm) {
        respondForm.addEventListener('submit', async function(e) {
            e.preventDefault();

            const applicationId = document.getElementById('respondApplicationId').value;
            if (!applicationId) {
                showNotification('Ошибка: не указана заявка', 'error');
                return;
            }

            const status = document.querySelector('input[name="status"]:checked')?.value;
            const answer = document.getElementById('respondAnswer').value;
            const durationDays = document.getElementById('respondDurationDays').value;
            const desiredDate = document.getElementById('respondNewDesiredDate').value;

            if (!status) {
                showNotification('Выберите решение', 'error');
                return;
            }

            const formData = new FormData();
            formData.append('status', status);
            if (answer) formData.append('answer', answer);
            if (durationDays) formData.append('duration_days', parseInt(durationDays));
            if (desiredDate) formData.append('desired_date', desiredDate);

            try {
                showNotification('Отправка ответа...', 'info');

                const response = await fetch(`/api/applications/${applicationId}/respond`, {
                    method: 'POST',
                    body: formData,
                    credentials: 'same-origin'
                });

                if (!response.ok) {
                    const err = await response.json();
                    throw new Error(err.detail || 'Ошибка отправки ответа');
                }

                showNotification('Ответ успешно отправлен!', 'success');
                closeModal('respondApplicationModal');

                // Обновляем список входящих заявок
                if (document.getElementById('incomingApplicationsModal').style.display === 'flex') {
                    loadIncomingApplications();
                }

            } catch (error) {
                console.error('Ошибка:', error);
                showNotification(error.message, 'error');
            }
        });
    }
});

// Переопределяем функцию closeModal для сброса кнопок
const originalCloseModal = closeModal;
closeModal = function(modalId) {
    if (modalId === 'propertyEditModal') {
        // Освобождаем blob URL
        allPhotos.forEach(p => {
            if (p.isNew && p.url && p.url.startsWith('blob:')) {
                URL.revokeObjectURL(p.url);
            }
        });
        allPhotos = [];
        deletedPhotoIds = [];
        updatePhotoCounter(); // Сброс счетчика
    }
    originalCloseModal(modalId);
};

function showIncomingContracts() {
    console.log('showIncomingContracts вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    loadContracts('incomingContractsList', false); // false - входящие (где я собственник/агент)
    openModal('incomingContractsModal');
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

            // Определяем статус и его отображение
            const statusConfig = {
                pending: { bg: '#fff3cd', color: '#856404', text: '⏳ На рассмотрении', icon: '🕒' },
                approved: { bg: '#d4edda', color: '#155724', text: '✅ Одобрена', icon: '✅' },
                rejected: { bg: '#f8d7da', color: '#721c24', text: '❌ Отклонена', icon: '❌' },
                cancelled: { bg: '#e9ecef', color: '#6c757d', text: '🚫 Отменена', icon: '🚫' },
                completed: { bg: '#cce5ff', color: '#004085', text: '✓ Завершена', icon: '✓' }
            };

            const status = statusConfig[app.status] || { bg: '#e9ecef', color: '#6c757d', text: app.status, icon: '❓' };

            // Форматируем дату
            const desiredDate = app.desired_date ? new Date(app.desired_date).toLocaleDateString('ru-RU') : 'не указана';

            // Формируем стоимость
            const priceDisplay = app.price ? `${Number(app.price).toLocaleString('ru-RU')} ₽/мес` : 'Цена не указана';

            // ===== ВАЖНО: определяем, показывать ли кнопку отмены =====
            // Кнопка отмены показывается ТОЛЬКО для статуса 'pending' (в ожидании)
            const showCancelButton = app.status === 'pending';

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
                            <span style="padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${status.bg}; color: ${status.color};">
                                ${status.icon} ${status.text}
                            </span>
                        </div>
                        <div style="font-weight: 700; color: #28a745; font-size: 16px;">${priceDisplay}</div>
                        ${app.answer ? `<div style="margin-top: 8px; font-size: 13px; color: #495057; background: #f8f9fa; padding: 8px; border-radius: 6px;"><strong>Ответ:</strong> ${app.answer}</div>` : ''}
                    </div>

                    <!-- Кнопки справа -->
                    <div style="display: flex; flex-direction: column; gap: 8px; min-width: 160px;">
                        <button class="btn-info" onclick="showApplicationDetail(${app.application_id})"
                                style="padding: 10px 12px; background: #17a2b8; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 500; display: flex; align-items: center; justify-content: center; gap: 5px;">
                            📋 Сведения о заявке
                        </button>

                        ${showCancelButton ?
                            `<button class="btn-danger" onclick="cancelApplication(${app.application_id})"
                                    style="padding: 10px 12px; background: #dc3545; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 500; display: flex; align-items: center; justify-content: center; gap: 5px;">
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
    const formattedPrice = Number(price).toLocaleString('ru-RU', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    });

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

// В static/script.js обновите функцию loadMyProperties

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
            container.innerHTML = '<div style="text-align: center; padding: 60px 20px; color: #6c757d;">У вас пока нет объектов</div>';
            return;
        }

        let html = '';
        properties.forEach(prop => {
            const priceDisplay = formatPrice(prop.price, prop.interval_pay);

            // Определяем класс и текст статуса
            let statusClass = '';
            let statusText = '';
            switch(prop.status) {
                case 'active':
                    statusClass = 'status-active';
                    statusText = 'Активно';
                    break;
                case 'draft':
                    statusClass = 'status-draft';
                    statusText = 'Черновик';
                    break;
                case 'rented':
                    statusClass = 'status-rented';
                    statusText = 'Сдано';
                    break;
                case 'archived':
                    statusClass = 'status-archived';
                    statusText = 'В архиве';
                    break;
                default:
                    statusClass = 'status-draft';
                    statusText = prop.status;
            }

            html += `
                <div class="property-item" style="display: flex; gap: 20px; padding: 20px; border-bottom: 1px solid #e9ecef; background: white; border-radius: 12px; margin-bottom: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.02);">
                    <!-- Фото объекта -->
                    <div style="width: 120px; height: 120px; flex-shrink: 0; border-radius: 8px; overflow: hidden; background: #f8f9fa; border: 1px solid #e9ecef;">
                        <img src="${prop.main_photo_url || '/resources/placeholder-image.png'}"
                             alt="Property"
                             style="width: 100%; height: 100%; object-fit: cover;"
                             onerror="this.src='/resources/placeholder-image.png'">
                    </div>

                    <!-- Информация об объекте -->
                    <div style="flex: 1; display: flex; flex-direction: column; gap: 8px;">
                        <div style="font-weight: 600; font-size: 18px; color: #212529;">${prop.title}</div>
                        <div style="color: #6c757d; font-size: 14px; display: flex; align-items: center; gap: 5px;">
                            <img src="/resources/pin.png" style="width: 14px; opacity: 0.5;"> ${prop.address}
                        </div>
                        <div style="display: flex; gap: 15px; font-size: 14px; color: #495057;">
                            <span>${prop.rooms} комн.</span>
                            <span>${prop.area} м²</span>
                            <span>${prop.property_type === 'apartment' ? 'Квартира' : prop.property_type === 'house' ? 'Дом' : 'Коммерческая'}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 5px;">
                            <span class="status-badge ${statusClass}">${statusText}</span>
                            <span style="font-weight: 700; color: #28a745; font-size: 18px;">${priceDisplay}</span>
                        </div>
                    </div>

                    <!-- Кнопки действий (однородные с другими модалками) -->
                    <div style="display: flex; flex-direction: column; gap: 8px; min-width: 140px;">
                        <button class="btn-primary" onclick="editProperty(${prop.property_id})"
                                style="padding: 10px; background: linear-gradient(135deg, #007bff 0%, #0056b3 100%); color: white; border: none; border-radius: 6px; font-weight: 500; font-size: 13px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 5px;">
                            <span>✎</span> Изменить
                        </button>
                        <button class="btn-danger" onclick="deleteProperty(${prop.property_id})"
                                style="padding: 10px; background: #dc3545; color: white; border: none; border-radius: 6px; font-weight: 500; font-size: 13px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 5px;">
                            <span>🗑</span> Удалить
                        </button>
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

// Класс для работы с городами
class CitySelector {
    constructor(inputId, datalistId) {
        this.input = document.getElementById(inputId);
        this.datalist = document.getElementById(datalistId);
        this.selectedCity = null;

        if (this.input && this.datalist) {
            this.init();
        }
    }

    init() {
        // Обработчик ввода
        this.input.addEventListener('input', () => {
            const query = this.input.value;

            if (query.length < 2) {
                this.hideDatalist();
                return;
            }

            // Поиск городов через API
            HH_API.searchCities(query, (cities) => {
                this.showResults(cities);
            });
        });

        // Закрытие по клику вне
        document.addEventListener('click', (e) => {
            if (!this.input.contains(e.target) && !this.datalist.contains(e.target)) {
                this.hideDatalist();
            }
        });

        // Выбор города
        this.input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                this.hideDatalist();
            }
        });
    }

    showResults(cities) {
        if (!cities || cities.length === 0) {
            this.hideDatalist();
            return;
        }

        let html = '';
        cities.forEach(city => {
            // Разделяем город и регион
            const match = city.match(/^(.*?)(?:\s*\(([^)]+)\))?$/);
            const cityName = match[1].trim();
            const region = match[2] || '';

            html += `
                <div class="city-option" onclick="citySelectors['${this.input.id}'].selectCity('${city.replace(/'/g, "\\'")}')">
                    <span class="city-name">${cityName}</span>
                    ${region ? `<span class="region-name">${region}</span>` : ''}
                </div>
            `;
        });

        this.datalist.innerHTML = html;
        this.datalist.classList.add('show');
    }

    selectCity(city) {
        this.input.value = city.split(' (')[0]; // Показываем только название города
        this.selectedCity = city;
        this.hideDatalist();

        // Обновляем верхнюю панель
        this.updateHeaderCity(city.split(' (')[0]);

        // Сохраняем полное название для отправки на сервер
        this.input.dataset.fullCity = city;
    }

    hideDatalist() {
        this.datalist.classList.remove('show');
    }

    updateHeaderCity(city) {
        const cityElement = document.getElementById('selectedCity');
        if (cityElement) {
            cityElement.textContent = city;
        }
    }
}

// Хранилище экземпляров CitySelector
window.citySelectors = {};

// Инициализация полей городов
function initCitySelectors() {
    if (document.getElementById('profileCity')) {
        window.citySelectors['profileCity'] = new CitySelector('profileCity', 'profileCityDatalist');
    }
    if (document.getElementById('city')) {
        window.citySelectors['city'] = new CitySelector('city', 'citySuggestions');
    }
}

// ==================== ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ ====================

// Валидация документов
function validateDocuments() {
    const passport = document.getElementById('profilePassport')?.value || '';
    const inn = document.getElementById('profileInn')?.value || '';
    const indicator = document.getElementById('docWarningIndicator');

    // Проверка паспорта (10 цифр)
    const isPassportValid = passport === '' || /^\d{10}$/.test(passport.replace(/\s/g, ''));

    // Проверка ИНН (10 или 12 цифр)
    const isInnValid = inn === '' || /^\d{10}$|^\d{12}$/.test(inn.replace(/\s/g, ''));

    const hasErrors = (passport && !isPassportValid) || (inn && !isInnValid);

    if (indicator) {
        indicator.style.display = hasErrors ? 'inline-block' : 'none';
    }

    return !hasErrors;
}

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

        validateDocuments();
        // Добавляем обработчики для полей документов
        const passportInput = document.getElementById('profilePassport');
        const innInput = document.getElementById('profileInn');

        if (passportInput) {
            passportInput.addEventListener('input', validateDocuments);
        }
        if (innInput) {
            innInput.addEventListener('input', validateDocuments);
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



// Обновление сетки фотографий
function updatePhotoGrid() {
    updatePhotoCounter();

    const existingContainer = document.getElementById('existingPhotosContainer');
    const newContainer = document.getElementById('newPhotosContainer');

    if (!existingContainer || !newContainer) return;

    // Отображаем существующие фото
    if (existingPhotos.length > 0) {
        existingContainer.innerHTML = renderPhotoItems(existingPhotos, 'existing');
    } else {
        existingContainer.innerHTML = '<div class="empty-photo-message">Нет сохранённых фотографий</div>';
    }

    // Отображаем новые фото
    if (newPhotos.length > 0) {
        newContainer.innerHTML = renderPhotoItems(newPhotos, 'new');
    } else {
        newContainer.innerHTML = ''; // можно оставить пустым или показать сообщение
    }

    // Добавляем обработчики drag & drop
    setupDragAndDrop();
}

function renderPhotos() {
    const existingContainer = document.getElementById('existingPhotosContainer');
    const newContainer = document.getElementById('newPhotosContainer');

    if (!existingContainer || !newContainer) return;

    // Существующие фото (isNew = false)
    const existing = allPhotos.filter(p => !p.isNew);
    // Новые фото (isNew = true)
    const news = allPhotos.filter(p => p.isNew);

    existingContainer.innerHTML = renderPhotoItems(existing, 'existing');
    newContainer.innerHTML = renderPhotoItems(news, 'new');

    // Обновляем счетчик при каждом рендере
    updatePhotoCounter();
}

// Обработка выбора новых фотографий
function handlePhotoSelect(event) {
    const files = Array.from(event.target.files);

    // Проверка лимита
    if (allPhotos.length + files.length > MAX_PHOTOS) {
        showNotification(`Можно загрузить не более ${MAX_PHOTOS} фотографий`, 'warning');
        return;
    }

    const validFiles = files.filter(file => file.type.startsWith('image/'));

    validFiles.forEach(file => {
        const id = 'new_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        allPhotos.push({
            id: id,
            url: URL.createObjectURL(file),
            is_main: allPhotos.length === 0, // Первое фото сразу главное
            isNew: true,
            file: file
        });
    });

    // Обновляем счетчик и отображение
    updatePhotoCounter();
    renderPhotos();

    // Очищаем input для возможности повторного выбора тех же файлов
    event.target.value = '';
}

function removePhoto(index) {
    if (window.uploadedFiles) {
        window.uploadedFiles.splice(index, 1);
        updatePhotoPreview();
    }
}

// Рендер элементов фотографий
function renderPhotoItems(photos, type) {
    if (photos.length === 0) return type === 'existing' ? '<div class="empty-photo-message">Нет сохранённых фотографий</div>' : '';

    return photos.map((photo, index) => {
        const isMain = photo.is_main;

        // Правильное отображение звездочки
        const starIcon = isMain ? '⭐' : '☆';
        const starClass = isMain ? 'active' : '';

        return `
            <div class="photo-item ${type}-photo ${isMain ? 'main-photo' : ''}"
                 data-id="${photo.id}"
                 data-type="${type}"
                 data-index="${index}"
                 draggable="true"
                 ondragstart="handleDragStart(event)"
                 ondragend="handleDragEnd(event)"
                 ondragover="handleDragOver(event)"
                 ondragleave="handleDragLeave(event)"
                 ondrop="handleDrop(event)">
                <img src="${photo.url}" class="photo-image" alt="photo" onerror="this.src='/resources/placeholder-image.png'">
                <div class="photo-actions">
                    <button class="photo-btn photo-btn-star ${starClass}"
                            onclick="setMainPhoto('${photo.id}')"
                            title="Главное фото">${starIcon}</button>
                    <button class="photo-btn photo-btn-delete" onclick="deletePhoto('${photo.id}')" title="Удалить">🗑️</button>
                </div>
                <div class="photo-info">
                    <span class="photo-index">#${index + 1}</span>
                    <span class="photo-badge ${type === 'existing' ? 'badge-existing' : 'badge-new'}">
                        ${type === 'existing' ? 'Сохранено' : 'Новое'}
                    </span>
                </div>
            </div>
        `;
    }).join('');
}

// Обновление счётчика фотографий
function updatePhotoCounter() {
    const counter = document.getElementById('photoCounter');
    if (counter) {
        counter.textContent = `${allPhotos.length}/${MAX_PHOTOS}`;
        console.log('Счетчик обновлен:', allPhotos.length, '/', MAX_PHOTOS);
    }
}

// Удаление фотографии
function deletePhoto(photoId) {
    if (!confirm('Удалить это фото?')) return;

    const index = allPhotos.findIndex(p => String(p.id) === String(photoId));
    if (index === -1) return;

    const photo = allPhotos[index];

    // Освобождаем blob URL для новых фото
    if (photo.isNew && photo.url && photo.url.startsWith('blob:')) {
        URL.revokeObjectURL(photo.url);
    } else if (!photo.isNew) {
        // Существующее фото – добавляем ID в список на удаление
        deletedPhotoIds.push(Number(photo.id));
    }

    // Удаляем фото из массива
    allPhotos.splice(index, 1);

    // Если удалили главное, назначаем новое первое
    if (!allPhotos.some(p => p.is_main) && allPhotos.length > 0) {
        allPhotos[0].is_main = true;
    }

    // Обновляем счетчик и отображение
    updatePhotoCounter();
    renderPhotos();
}

// Установка главного фото
function setMainPhoto(photoId) {
    allPhotos.forEach(p => p.is_main = false);

    const photo = allPhotos.find(p => String(p.id) === String(photoId));
    if (photo) {
        photo.is_main = true;
    }

    renderPhotos();
}


// Эту функцию можно удалить или оставить пустой
function setupDragAndDrop() {
    // Обработчики уже привязаны через HTML-атрибуты
    console.log('Drag & drop инициализирован через HTML');
}

function handleDragStart(event) {
    const el = event.currentTarget;
    if (!el.dataset.id) {
        console.error('Нет data-id у элемента');
        return;
    }
    el.classList.add('dragging');
    draggedItem = el;
    event.dataTransfer.setData('text/plain', el.dataset.id);
    event.dataTransfer.effectAllowed = 'move';
}

function handleDragEnd(event) {
    const el = event.currentTarget;
    el.classList.remove('dragging');
    document.querySelectorAll('.photo-item').forEach(item => {
        item.classList.remove('drag-over', 'drag-over-top', 'drag-over-bottom');
    });
    draggedItem = null;
}

function handleDragOver(event) {
    event.preventDefault();
    const target = event.currentTarget;
    if (!target || target === draggedItem) return;
    event.dataTransfer.dropEffect = 'move';

    const rect = target.getBoundingClientRect();
    const mouseY = event.clientY;
    const middle = rect.top + rect.height / 2;

    target.classList.remove('drag-over-top', 'drag-over-bottom');
    if (mouseY < middle) {
        target.classList.add('drag-over-top');
    } else {
        target.classList.add('drag-over-bottom');
    }
}

function handleDragLeave(event) {
    event.currentTarget.classList.remove('drag-over', 'drag-over-top', 'drag-over-bottom');
}

function handleDrop(event) {
    event.preventDefault();
    const target = event.currentTarget;
    target.classList.remove('drag-over', 'drag-over-top', 'drag-over-bottom');

    if (!draggedItem || target === draggedItem) return;

    const draggedId = event.dataTransfer.getData('text/plain');
    const targetId = target.dataset.id;
    if (!draggedId || !targetId) return;

    const draggedIndex = allPhotos.findIndex(p => String(p.id) === String(draggedId));
    const targetIndex = allPhotos.findIndex(p => String(p.id) === String(targetId));

    if (draggedIndex === -1 || targetIndex === -1) return;

    // Перемещаем элемент
    const [draggedPhoto] = allPhotos.splice(draggedIndex, 1);
    const newIndex = draggedIndex < targetIndex ? targetIndex - 1 : targetIndex;
    allPhotos.splice(newIndex, 0, draggedPhoto);

    // Первое фото становится главным
    allPhotos.forEach((photo, index) => {
        photo.is_main = (index === 0);
    });

    // Обновляем счетчик и отображение
    updatePhotoCounter();
    renderPhotos();
}

// Перемещение фото между массивами (existing <-> new)
function movePhotoBetweenArrays(draggedId, draggedType, targetType, targetId) {
    console.log(`Перемещение между массивами: ${draggedId} (${draggedType}) -> ${targetType}`);

    if (draggedType === 'existing' && targetType === 'new') {
        // Перемещаем из existing в new
        const sourceIndex = existingPhotos.findIndex(p => p.photo_id == draggedId);
        if (sourceIndex !== -1) {
            const movedPhoto = { ...existingPhotos[sourceIndex] };

            // Удаляем из existing
            existingPhotos.splice(sourceIndex, 1);

            // Создаём временный ID для нового блока
            const newId = 'new_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);

            // Добавляем в new
            newPhotos.push({
                id: newId,
                url: movedPhoto.url,
                is_main: movedPhoto.is_main,
                file: null, // Файла нет
                from_existing: true,
                original_id: movedPhoto.photo_id
            });

            // Помечаем оригинал для удаления
            if (!deletedPhotoIds.includes(movedPhoto.photo_id)) {
                deletedPhotoIds.push(movedPhoto.photo_id);
            }

            showNotification('Фото перемещено в новые', 'info');
        }
    } else if (draggedType === 'new' && targetType === 'existing') {
        // Перемещаем из new в existing
        const sourceIndex = newPhotos.findIndex(p => p.id === draggedId);
        if (sourceIndex !== -1) {
            const movedPhoto = newPhotos[sourceIndex];

            // Если это фото было перемещено из existing обратно
            if (movedPhoto.from_existing && movedPhoto.original_id) {
                // Удаляем из deletedPhotoIds
                const delIndex = deletedPhotoIds.indexOf(movedPhoto.original_id);
                if (delIndex !== -1) deletedPhotoIds.splice(delIndex, 1);

                // Возвращаем в existing с оригинальным ID
                existingPhotos.push({
                    photo_id: movedPhoto.original_id,
                    url: movedPhoto.url,
                    is_main: movedPhoto.is_main
                });
            } else {
                // Это новое загруженное фото - создаём запись для existing (но без файла)
                // Такое фото должно быть загружено на сервер при сохранении
                existingPhotos.push({
                    photo_id: 'temp_' + Date.now(),
                    url: movedPhoto.url,
                    is_main: movedPhoto.is_main,
                    is_new: true,
                    file: movedPhoto.file
                });
            }

            // Удаляем из new и освобождаем URL
            if (movedPhoto.url && movedPhoto.url.startsWith('blob:')) {
                URL.revokeObjectURL(movedPhoto.url);
            }
            newPhotos.splice(sourceIndex, 1);

            showNotification('Фото возвращено в существующие', 'info');
        }
    }
}

// Перемещение фото внутри одного массива
// Перемещение фото внутри одного массива
function movePhotoWithinArray(draggedId, targetId, type) {
    const array = type === 'existing' ? existingPhotos : newPhotos;
    const idField = type === 'existing' ? 'photo_id' : 'id';

    // Находим индексы
    const draggedIndex = array.findIndex(p => String(p[idField]) === String(draggedId));
    const targetIndex = array.findIndex(p => String(p[idField]) === String(targetId));

    if (draggedIndex !== -1 && targetIndex !== -1 && draggedIndex !== targetIndex) {
        // Удаляем перетаскиваемый элемент
        const [draggedItem] = array.splice(draggedIndex, 1);

        // Вставляем на новое место
        const newIndex = draggedIndex < targetIndex ? targetIndex - 1 : targetIndex;
        array.splice(newIndex, 0, draggedItem);

        // ВАЖНО: После перетаскивания ПЕРВОЕ ФОТО становится главным
        array.forEach((photo, index) => {
            photo.is_main = (index === 0);
        });

        console.log(`✅ Элемент перемещён с позиции ${draggedIndex} на ${newIndex}`);
        renderPhotos(); // Обновляем отображение
    }
}

// Отображение существующих фотографий при редактировании
function displayExistingPhotos(photos) {
    existingPhotos = photos.map(photo => ({
        ...photo,
        is_main: photo.is_main || false
    }));
    newPhotos = [];
    deletedPhotoIds = [];
    updatePhotoGrid();
}

// Сбор данных для отправки на сервер
async function uploadPropertyPhotos(propertyId) {
    if (newPhotos.length === 0) return [];

    const formData = new FormData();
    newPhotos.forEach(photo => {
        if (photo.file) {
            formData.append('photos', photo.file);
        }
    });

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
        showNotification(`Загружено ${result.uploaded} фотографий`, 'success');
        return result;

    } catch (error) {
        console.error('❌ Ошибка загрузки фото:', error);
        showNotification('Ошибка при загрузке фотографий', 'error');
        throw error;
    }
}

// Удаление фотографий на сервере
async function deletePropertyPhotos(propertyId, photoIds) {
    if (photoIds.length === 0) return;

    // Для каждого ID отправляем запрос на удаление
    // (нужен соответствующий эндпоинт на сервере)
    for (const photoId of photoIds) {
        try {
            await fetch(`/api/properties/${propertyId}/photos/${photoId}`, {
                method: 'DELETE',
                credentials: 'same-origin'
            });
        } catch (error) {
            console.error(`Ошибка удаления фото ${photoId}:`, error);
        }
    }
}

function formatFileSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function updatePhotoPreview() {
    const container = document.getElementById('photoPreviewContainer');
    const existingContainer = document.getElementById('existingPhotosContainer');
    const counter = document.getElementById('photoCounter');

    if (!container) return;

    if (counter) {
        counter.textContent = `${window.uploadedFiles ? window.uploadedFiles.length : 0}/${MAX_PHOTOS}`;
    }

    // Очищаем контейнер существующих фото, если мы загружаем новые
    if (existingContainer) {
        existingContainer.innerHTML = '';
    }

    if (!window.uploadedFiles || window.uploadedFiles.length === 0) {
        // Не очищаем, если есть существующие фото - они должны отображаться отдельно
        return;
    }

    let html = '';
    window.uploadedFiles.forEach((file, index) => {
        const url = URL.createObjectURL(file);
        html += `
            <div class="photo-preview-block">
                <div class="photo-preview-image">
                    <img src="${url}" alt="Preview" onload="(function(img){
                        setTimeout(function(){
                            URL.revokeObjectURL(img.src);
                        }, 1000);
                    })(this)">
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
        document.getElementById('propCurrentStatus').value = '';
    }
    document.getElementById('propertyEditTitle').textContent = 'Добавление объекта';

    // Очищаем фотографии
    allPhotos = [];
    deletedPhotoIds = [];

    // Обновляем счетчик и отображение
    updatePhotoCounter();
    renderPhotos();

    // В режиме создания показываем все кнопки
    const cancelBtn = document.querySelector('#propertyEditForm .btn-secondary');
    const draftBtn = document.querySelector('#propertyEditForm .btn-warning');
    const publishBtn = document.querySelector('#propertyEditForm .btn-primary');

    if (cancelBtn && draftBtn && publishBtn) {
        draftBtn.style.display = 'block';
        draftBtn.textContent = '💾 Сохранить как черновик';
        draftBtn.onclick = () => submitPropertyForm('draft');

        publishBtn.textContent = '📢 Опубликовать';
        publishBtn.onclick = () => submitPropertyForm('active');

        publishBtn.style.display = 'block';
        cancelBtn.style.display = 'block';
    }

    openModal('propertyEditModal');
}

// Функция для обновления кнопок в зависимости от статуса
function updatePropertyEditButtonsForEditing(currentStatus) {
    const cancelBtn = document.querySelector('#propertyEditForm .btn-secondary');
    const draftBtn = document.querySelector('#propertyEditForm .btn-warning');
    const publishBtn = document.querySelector('#propertyEditForm .btn-primary');

    if (!cancelBtn || !draftBtn || !publishBtn) return;

    if (currentStatus === 'active' || currentStatus === 'rented') {
        draftBtn.style.display = 'none';
        publishBtn.textContent = '💾 Сохранить изменения';
        publishBtn.onclick = () => submitPropertyForm(currentStatus);
        cancelBtn.style.display = 'block';
    } else {
        draftBtn.style.display = 'block';
        draftBtn.textContent = '💾 Обновить черновик';
        draftBtn.onclick = () => submitPropertyForm('draft');
        publishBtn.textContent = '📢 Опубликовать';
        publishBtn.onclick = () => submitPropertyForm('active');
        cancelBtn.style.display = 'block';
    }
}

async function editProperty(propertyId) {
    console.log('editProperty вызван для ID:', propertyId);
    try {
        const response = await fetch(`/api/property/${propertyId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Не удалось загрузить данные');

        const prop = await response.json();
        console.log('Загруженные данные объекта:', prop);

        // Заполняем форму
        document.getElementById('propTitle').value = prop.title || '';
        document.getElementById('propDescription').value = prop.description || '';
        document.getElementById('propAddress').value = prop.address || '';
        document.getElementById('propCity').value = prop.city || '';
        document.getElementById('propType').value = prop.property_type || 'apartment';
        document.getElementById('propArea').value = prop.area || '';
        document.getElementById('propRooms').value = prop.rooms || '';
        document.getElementById('propPrice').value = prop.price || '';
        document.getElementById('propInterval').value = prop.interval_pay || 'month';
        document.getElementById('propCurrentStatus').value = prop.status || 'draft';

        // Загружаем существующие фото
        allPhotos = [];
        if (prop.photos && prop.photos.length > 0) {
            allPhotos = prop.photos.map((photo, index) => ({
                id: photo.photo_id || photo.id,
                url: photo.url,
                is_main: index === 0, // Первое фото главное
                isNew: false,
                file: null
            }));
        }

        deletedPhotoIds = [];

        // Обновляем счетчик и отображение
        updatePhotoCounter();
        renderPhotos();

        document.getElementById('propertyEditForm').dataset.propertyId = propertyId;
        document.getElementById('propertyEditTitle').textContent = 'Редактирование объекта';
        updatePropertyEditButtonsForEditing(prop.status);
        openModal('propertyEditModal');

    } catch (error) {
        console.error('Ошибка в editProperty:', error);
        showNotification(error.message, 'error');
    }
}

function displayExistingPhotos(photos) {
    const container = document.getElementById('photoPreviewContainer');
    const existingContainer = document.getElementById('existingPhotosContainer');
    if (!container) return;

    if (!photos || photos.length === 0) {
        container.innerHTML = '<div class="empty-preview">Фотографии не загружены</div>';
        if (existingContainer) existingContainer.innerHTML = '';
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
    if (existingContainer) existingContainer.innerHTML = ''; // очищаем старые фото
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

// Загрузить список диалогов с WebSocket обновлениями
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

            let avatarHtml = '';
            if (dialog.avatar_url) {
                avatarHtml = `<img src="${dialog.avatar_url}" style="width: 100%; height: 100%; object-fit: cover;">`;
            } else {
                avatarHtml = `<span style="color: white; font-weight: 600; font-size: 18px;">${dialog.user_initials || '?'}</span>`;
            }

            html += `
                <div class="dialog-item" data-user-id="${dialog.user_id}" onclick="openChat(${dialog.user_id})"
                     style="display: flex; align-items: center; gap: 15px; padding: 15px; border-bottom: 1px solid #e9ecef; cursor: pointer; transition: background 0.2s;">
                    <div style="position: relative;">
                        <div class="dialog-avatar" style="width: 50px; height: 50px; border-radius: 50%; overflow: hidden; background: linear-gradient(135deg, #007bff, #0056b3); display: flex; align-items: center; justify-content: center;">
                            ${avatarHtml}
                        </div>

                        <span class="online-dot" data-user-id="${dialog.user_id}"
                              style="position: absolute; bottom: 2px; right: 2px; width: 12px; height: 12px; border-radius: 50%; background: #6c757d; border: 2px solid white;"></span>
                    </div>

                    <div style="flex: 1;">
                        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
                            <span style="font-weight: 600; font-size: 16px;">${dialog.user_name || 'Пользователь'}</span>
                            ${dialog.unread > 0 ? `<span class="unread-badge" data-user-id="${dialog.user_id}" style="background: #007bff; color: white; border-radius: 20px; padding: 2px 8px; font-size: 11px; font-weight: 600;">${dialog.unread}</span>` : ''}
                        </div>
                        <div style="color: ${dialog.unread > 0 ? '#212529' : '#6c757d'}; font-size: 14px; display: flex; justify-content: space-between;">
                            <span style="font-weight: ${dialog.unread > 0 ? '500' : 'normal'};">${dialog.last_message || 'Нет сообщений'}</span>
                            <span style="font-size: 11px; color: #999; margin-left: 10px;">${lastTimeText || ''}</span>
                        </div>
                    </div>
                </div>
            `;
        }
        container.innerHTML = html;

        // Запрашиваем статусы
        updateOnlineStatuses(dialogs);

    } catch (error) {
        console.error('Ошибка загрузки диалогов:', error);
        showNotification('Ошибка загрузки диалогов', 'error');
    }
}

// Обновление онлайн статусов
function updateOnlineStatuses(dialogs) {
    dialogs.forEach(async (dialog) => {
        try {
            const statusResponse = await fetch(`/api/user/${dialog.user_id}/status`, { credentials: 'same-origin' });
            if (statusResponse.ok) {
                const statusData = await statusResponse.json();
                updateUserOnlineStatus(dialog.user_id, statusData.is_online);
            }
        } catch (e) {
            console.error(`Ошибка получения статуса:`, e);
        }
    });
}

// Настройка обработчика печатания
function setupTypingHandler(toUserId) {
    const input = document.getElementById('messageInput');
    if (!input) return;

    input.addEventListener('input', function() {
        if (typingTimeout) {
            clearTimeout(typingTimeout);
        } else {
            // Начал печатать - отправляем статус
            sendWebSocketMessage({
                type: 'typing',
                to_user_id: toUserId,
                is_typing: true
            });
        }

        // Через 2 секунды после остановки отправляем "перестал печатать"
        typingTimeout = setTimeout(() => {
            sendWebSocketMessage({
                type: 'typing',
                to_user_id: toUserId,
                is_typing: false
            });
            typingTimeout = null;
        }, 2000);
    });
}

// Открыть чат (исправленная)
async function openChat(userId) {
    console.log('openChat', userId);
    currentChatUserId = userId;

    try {
        const response = await fetch(`/api/user/${userId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки данных пользователя');

        const userData = await response.json();

        // Сохраняем имя собеседника
        currentChatUserName = userData.full_name || 'Пользователь';

        // Обновляем шапку чата
        document.getElementById('chatUserName').textContent = currentChatUserName;

        const avatarContainer = document.getElementById('chatAvatarContainer');
        if (avatarContainer) {
            if (userData.avatar_url) {
                avatarContainer.innerHTML = `<img src="${userData.avatar_url}" style="width: 45px; height: 45px; border-radius: 50%; object-fit: cover;">`;
            } else {
                const initials = getInitials(userData.full_name) || userData.email?.[0]?.toUpperCase() || '?';
                avatarContainer.innerHTML = `<span style="color: white; font-weight: 600; font-size: 16px;">${initials}</span>`;
            }
        }

        // Получаем статус
        try {
            const statusResponse = await fetch(`/api/user/${userId}/status`, { credentials: 'same-origin' });
            if (statusResponse.ok) {
                const statusData = await statusResponse.json();
                updateUserStatus(statusData.is_online);
            }
        } catch (e) {
            updateUserStatus(false);
        }

        // Загружаем сообщения
        await loadMessages(userId);

        closeModal('dialogsListModal');
        openModal('chatModal');

        // Добавляем обработчик печатания
        setupTypingHandler(userId);

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка загрузки данных', 'error');
    }
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

// Загрузить сообщения (исправленная)
async function loadMessages(userId) {
    try {
        const response = await fetch(`/api/messages?chat_with=${userId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки сообщений');

        const data = await response.json();

        const messagesContainer = document.getElementById('chatMessages');
        if (!messagesContainer) return;

        if (!data.messages || data.messages.length === 0) {
            messagesContainer.innerHTML = '<p style="text-align: center; padding: 40px; color: #6c757d;">Нет сообщений</p>';
            return;
        }

        let html = '';
        let currentDate = null;
        let messageCount = 0;

        data.messages.forEach((msg, index) => {
            const msgDate = new Date(msg.created_at);
            const msgDateStr = msgDate.toDateString();

            // Добавляем разделитель только если день изменился
            if (msgDateStr !== currentDate) {
                // Если это не первое сообщение, добавляем отступ
                if (currentDate !== null) {
                    html += '<div style="height: 10px;"></div>';
                }
                html += getDateSeparator(msgDate);
                currentDate = msgDateStr;
                messageCount = 0;
            }

            if (msg.is_mine) {
                html += `
                    <div style="display: flex; justify-content: flex-end; margin-bottom: 8px;">
                        <div style="background: #007bff; color: white; padding: 10px 15px; border-radius: 18px 18px 4px 18px; max-width: 70%; word-wrap: break-word;">
                            ${msg.content}
                            <div style="display: flex; align-items: center; justify-content: flex-end; gap: 4px; font-size: 11px; opacity: 0.7; margin-top: 4px;">
                                <span>${formatMessageTime(msg.created_at)}</span>
                                <span class="message-status" data-message-id="${msg.id}">${msg.is_read ? '✓✓' : '✓'}</span>
                            </div>
                        </div>
                    </div>
                `;
            } else {
                html += `
                    <div style="display: flex; justify-content: flex-start; margin-bottom: 8px;">
                        <div style="background: white; padding: 10px 15px; border-radius: 18px 18px 18px 4px; max-width: 70%; box-shadow: 0 1px 2px rgba(0,0,0,0.1); word-wrap: break-word;">
                            ${msg.content}
                            <div style="font-size: 11px; color: #6c757d; margin-top: 4px;" class="message-time" data-datetime="${msg.created_at}">${formatMessageTime(msg.created_at)}</div>
                        </div>
                    </div>
                `;
            }
            messageCount++;
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

// Функция для получения иконки статуса сообщения
function getMessageStatusIcon(isRead) {
    if (isRead) {
        // Двойная галочка - прочитано
        return '<span style="display: inline-flex; align-items: center; margin-left: 4px; color: #fff;">✓✓</span>';
    } else {
        // Одинарная галочка - отправлено, но не прочитано
        return '<span style="display: inline-flex; align-items: center; margin-left: 4px; color: rgba(255,255,255,0.7);">✓</span>';
    }
}

// Функция для разделителя дней (исправленная)
function getDateSeparator(date) {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    // Сбрасываем время для корректного сравнения
    today.setHours(0, 0, 0, 0);
    yesterday.setHours(0, 0, 0, 0);
    const compareDate = new Date(date);
    compareDate.setHours(0, 0, 0, 0);

    let dateText = '';
    if (compareDate.getTime() === today.getTime()) {
        dateText = 'Сегодня';
    } else if (compareDate.getTime() === yesterday.getTime()) {
        dateText = 'Вчера';
    } else {
        dateText = date.toLocaleDateString('ru-RU', {
            day: 'numeric',
            month: 'long',
            year: date.getFullYear() !== today.getFullYear() ? 'numeric' : undefined
        });
    }

    return `
        <div class="date-separator" data-date="${date.toISOString()}"
             style="display: flex; justify-content: center; margin: 20px 0 10px 0;">
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

// Отправка сообщения с улучшенной обработкой
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

        const result = await response.json();

        // Очищаем поле ввода
        document.getElementById('messageInput').value = '';

        // Отправляем статус "перестал печатать"
        sendWebSocketMessage({
            type: 'typing',
            to_user_id: toUserId,
            is_typing: false
        });

        // Добавляем сообщение в чат (оптимистичное обновление)
        const tempMessage = {
            id: result.message_id,
            from_user_id: currentUserId,
            to_user_id: toUserId,
            content: content.trim(),
            created_at: new Date().toISOString(),
            is_read: false,
            is_mine: true
        };

        appendMyMessageToChat(tempMessage);

    } catch (error) {
        console.error('Ошибка отправки сообщения:', error);
        showNotification(error.message, 'error');
    }
}

// Добавление своего сообщения в чат (исправленная)
function appendMyMessageToChat(message) {
    const messagesContainer = document.getElementById('chatMessages');
    if (!messagesContainer) return;

    const msgDate = new Date(message.created_at);
    const lastMessage = messagesContainer.lastElementChild;

    // Проверяем, нужно ли добавить разделитель даты
    let needsSeparator = true;

    if (lastMessage) {
        // Ищем последний разделитель даты
        const separators = messagesContainer.querySelectorAll('.date-separator');
        if (separators.length > 0) {
            const lastSeparator = separators[separators.length - 1];
            const lastDate = new Date(lastSeparator.dataset.date);

            // Если последний разделитель для той же даты, не добавляем новый
            if (isSameDay(lastDate, msgDate)) {
                needsSeparator = false;
            }
        } else {
            // Если нет разделителей, добавляем
            needsSeparator = true;
        }
    } else {
        // Если нет сообщений, добавляем
        needsSeparator = true;
    }

    if (needsSeparator) {
        messagesContainer.insertAdjacentHTML('beforeend', getDateSeparator(msgDate));
    }

    // Добавляем сообщение
    const messageHtml = `
        <div style="display: flex; justify-content: flex-end; margin-bottom: 8px;">
            <div style="background: #007bff; color: white; padding: 10px 15px; border-radius: 18px 18px 4px 18px; max-width: 70%; word-wrap: break-word;">
                ${message.content}
                <div style="display: flex; align-items: center; justify-content: flex-end; gap: 4px; font-size: 11px; opacity: 0.7; margin-top: 4px;">
                    <span>${formatMessageTime(message.created_at)}</span>
                    <span class="message-status">✓</span>
                </div>
            </div>
        </div>
    `;

    messagesContainer.insertAdjacentHTML('beforeend', messageHtml);

    // Прокручиваем вниз
    const container = document.getElementById('chatMessagesContainer');
    if (container) {
        container.scrollTop = container.scrollHeight;
    }
}

// Обновление статусов прочтения
function updateMessageReadStatus(messageIds) {
    const messages = document.querySelectorAll('.message-status');
    messages.forEach(msg => {
        msg.textContent = '✓✓';
        msg.style.color = '#53bdeb';
    });
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
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 10;
let heartbeatInterval = null;
let typingTimeout = null;

// Получить ID текущего пользователя
function getCurrentUserId() {
    // Из data-атрибута
    const userData = document.getElementById('user-data');
    if (userData && userData.dataset.userId && userData.dataset.userId !== '') {
        return parseInt(userData.dataset.userId);
    }
    // Из глобальной переменной
    if (window.currentUser && window.currentUser.id) {
        return window.currentUser.id;
    }
    return null;
}

// Инициализация WebSocket соединения
function initWebSocket() {
    const userId = getCurrentUserId();

    if (!userId) {
        console.warn('⚠️ Нет ID пользователя, WebSocket не инициализируется');
        return;
    }

    currentUserId = userId;

    // Закрываем старый сокет
    if (socket) {
        try {
            socket.close();
        } catch (e) {}
    }

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/${userId}`;

    console.log('🔄 Подключение к WebSocket:', wsUrl);

    try {
        socket = new WebSocket(wsUrl);

        socket.onopen = function() {
            console.log('✅ WebSocket соединение установлено');
            reconnectAttempts = 0;

            // Запускаем heartbeat
            startHeartbeat();

            // Отправляем запрос на получение списка онлайн
            sendWebSocketMessage({ type: 'get_online' });
        };

        socket.onmessage = function(event) {
            try {
                const data = JSON.parse(event.data);
                handleWebSocketMessage(data);
            } catch (e) {
                console.error('❌ Ошибка парсинга сообщения:', e);
            }
        };

        socket.onclose = function() {
            console.log('❌ WebSocket соединение закрыто');
            stopHeartbeat();

            // Переподключение
            if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
                reconnectAttempts++;
                const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);
                console.log(`🔄 Переподключение через ${delay}ms...`);
                setTimeout(initWebSocket, delay);
            }
        };

        socket.onerror = function(error) {
            console.error('❌ WebSocket ошибка:', error);
        };

    } catch (error) {
        console.error('❌ Ошибка создания WebSocket:', error);
    }
}

// Отправка сообщения через WebSocket
function sendWebSocketMessage(data) {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify(data));
    }
}

// Обработка входящих WebSocket сообщений
function handleWebSocketMessage(data) {
    console.log('📨 WebSocket сообщение:', data);

    switch (data.type) {
        case 'status_update':
            updateUserOnlineStatus(data.user_id, data.is_online);
            break;

        case 'online_list':
            console.log('📋 Онлайн пользователи:', data.online_users);
            data.online_users.forEach(userId => {
                if (userId != currentUserId) {
                    updateUserOnlineStatus(userId, true);
                }
            });
            break;

        case 'new_message':
            handleNewMessage(data);
            break;

        case 'typing':
            handleTypingStatus(data);
            break;

        case 'messages_read':
            handleMessagesRead(data);
            break;

        case 'pong':
            // Heartbeat response
            break;
    }
}

// Глобальная переменная для отслеживания последнего количества уведомлений
let lastUnreadCount = 0;

// Обновление бейджа с миганием
function updateBadge(badgeId, count, shouldFlash = false) {
    const badge = document.getElementById(badgeId);
    if (!badge) return;

    if (count > 0) {
        badge.textContent = count > 99 ? '99+' : count;
        badge.style.display = 'flex';

        // Мигание при появлении новых уведомлений
        if (shouldFlash && count > lastUnreadCount) {
            badge.classList.add('blink');
            setTimeout(() => badge.classList.remove('blink'), 3000);
        }
    } else {
        badge.style.display = 'none';
    }

    // Обновляем последнее значение для этого бейджа
    if (badgeId === 'notificationsBadge') {
        lastUnreadCount = count;
    }
}

async function updateBadges() {
    const notificationsBadge = document.getElementById('notificationsBadge');
    const messagesBadge = document.getElementById('messagesBadge');

    try {
        // Получаем количество непрочитанных СИСТЕМНЫХ уведомлений (from_user_id IS NULL)
        const notifResponse = await fetch('/api/notifications/unread-count', { credentials: 'same-origin' });
        if (notifResponse.ok) {
            const notifData = await notifResponse.json();
            if (notificationsBadge) {
                if (notifData.count > 0) {
                    notificationsBadge.textContent = notifData.count > 99 ? '99+' : notifData.count;
                    notificationsBadge.style.display = 'flex';
                } else {
                    notificationsBadge.style.display = 'none';
                }
            }
        }

        // Получаем количество непрочитанных ЛИЧНЫХ сообщений (from_user_id IS NOT NULL)
        const msgResponse = await fetch('/api/messages/unread-count', { credentials: 'same-origin' });
        if (msgResponse.ok) {
            const msgData = await msgResponse.json();
            if (messagesBadge) {
                if (msgData.count > 0) {
                    messagesBadge.textContent = msgData.count > 99 ? '99+' : msgData.count;
                    messagesBadge.style.display = 'flex';
                } else {
                    messagesBadge.style.display = 'none';
                }
            }
        }
    } catch (error) {
        console.error('Ошибка обновления бейджей:', error);
    }
}


async function updateBadgesWithFlash() {
    const messagesBadge = document.getElementById('messagesBadge');

    try {
        const msgResponse = await fetch('/api/messages/unread-count', { credentials: 'same-origin' });
        if (msgResponse.ok) {
            const msgData = await msgResponse.json();
            const currentCount = msgData.count;

            if (messagesBadge) {
                if (currentCount > 0) {
                    messagesBadge.textContent = currentCount > 99 ? '99+' : currentCount;
                    messagesBadge.style.display = 'flex';

                    // Мигание при появлении нового сообщения
                    if (currentCount > lastUnreadCount) {
                        messagesBadge.classList.add('blink');
                        setTimeout(() => messagesBadge.classList.remove('blink'), 3000);
                    }
                } else {
                    messagesBadge.style.display = 'none';
                }
            }

            lastUnreadCount = currentCount;
        }

        // Обновляем уведомления без мигания
        const notifResponse = await fetch('/api/notifications/unread-count', { credentials: 'same-origin' });
        if (notifResponse.ok) {
            const notifData = await notifResponse.json();
            const notifBadge = document.getElementById('notificationsBadge');
            if (notifBadge) {
                if (notifData.count > 0) {
                    notifBadge.textContent = notifData.count > 99 ? '99+' : notifData.count;
                    notifBadge.style.display = 'flex';
                } else {
                    notifBadge.style.display = 'none';
                }
            }
        }

    } catch (error) {
        console.error('Ошибка обновления бейджей:', error);
    }
}

// Обновление бейджей через REST API
async function updateBadgesFromServer() {
    try {
        const response = await fetch('/api/my/dialogs', { credentials: 'same-origin' });
        if (response.ok) {
            const dialogs = await response.json();
            updateBadges(dialogs);
        }
    } catch (error) {
        console.error('Ошибка обновления бейджей:', error);
    }
}

// Обработка нового сообщения через WebSocket
async function handleNewMessage(data) {
    console.log('📨 Новое сообщение:', data);

    if (data.from_user_id === 0) { // системное уведомление
        // Обновляем бейдж уведомлений (без мигания)
        await updateBadges();

        // Если окно уведомлений открыто, перезагружаем список
        const notificationsDropdown = document.getElementById('notificationsDropdown');
        if (notificationsDropdown && notificationsDropdown.classList.contains('show')) {
            loadSystemNotifications();
        }

    } else { // личное сообщение
        // Обновляем бейдж сообщений С МИГАНИЕМ
        await updateBadgesWithFlash();

        // Если чат с этим пользователем открыт, добавляем сообщение
        if (currentChatUserId === data.from_user_id) {
            appendMessageToChat(data.message);
        } else {
            showNotification('💬 Новое сообщение', 'info');

            // Если окно диалогов открыто, обновляем список
            if (document.getElementById('dialogsListModal').style.display === 'flex') {
                loadDialogsList();
            }
        }

        // Если окно сообщений открыто, обновляем список
        const messagesDropdown = document.getElementById('messagesDropdown');
        if (messagesDropdown && messagesDropdown.classList.contains('show')) {
            loadRecentMessages();
        }
    }
}

// Добавление сообщения от собеседника в чат (исправленная)
function appendMessageToChat(message) {
    const messagesContainer = document.getElementById('chatMessages');
    if (!messagesContainer) return;

    const msgDate = new Date(message.created_at);
    const lastMessage = messagesContainer.lastElementChild;

    // Проверяем, нужно ли добавить разделитель даты
    let needsSeparator = true;

    if (lastMessage) {
        // Ищем последний разделитель даты
        const separators = messagesContainer.querySelectorAll('.date-separator');
        if (separators.length > 0) {
            const lastSeparator = separators[separators.length - 1];
            const lastDate = new Date(lastSeparator.dataset.date);

            // Если последний разделитель для той же даты, не добавляем новый
            if (isSameDay(lastDate, msgDate)) {
                needsSeparator = false;
            }
        } else {
            // Если нет разделителей, добавляем
            needsSeparator = true;
        }
    } else {
        // Если нет сообщений, добавляем
        needsSeparator = true;
    }

    if (needsSeparator) {
        messagesContainer.insertAdjacentHTML('beforeend', getDateSeparator(msgDate));
    }

    // Добавляем сообщение
    const messageHtml = `
        <div style="display: flex; justify-content: flex-start; margin-bottom: 8px;">
            <div style="background: white; padding: 10px 15px; border-radius: 18px 18px 18px 4px; max-width: 70%; box-shadow: 0 1px 2px rgba(0,0,0,0.1); word-wrap: break-word;">
                ${message.content}
                <div style="font-size: 11px; color: #6c757d; margin-top: 4px;">${formatMessageTime(message.created_at)}</div>
            </div>
        </div>
    `;

    messagesContainer.insertAdjacentHTML('beforeend', messageHtml);

    // Прокручиваем вниз
    const container = document.getElementById('chatMessagesContainer');
    if (container) {
        container.scrollTop = container.scrollHeight;
    }
}

// Обработка статуса печатания
function handleTypingStatus(data) {
    if (currentChatUserId === data.user_id) {
        const typingIndicator = document.getElementById('typingIndicator');

        if (typingIndicator) {
            if (data.is_typing) {
                // Используем имя из шапки чата (оно уже содержит имя собеседника)
                typingIndicator.style.display = 'block';
            } else {
                typingIndicator.style.display = 'none';
            }
        }
    }
}

// Обработка прочтения сообщений
function handleMessagesRead(data) {
    if (currentChatUserId === data.user_id) {
        // Обновляем статусы сообщений в чате
        updateMessageReadStatus(data.message_ids);
    }
}

// Heartbeat для поддержания соединения
function startHeartbeat() {
    if (heartbeatInterval) {
        clearInterval(heartbeatInterval);
    }
    heartbeatInterval = setInterval(() => {
        sendWebSocketMessage({ type: 'ping' });
    }, 30000); // Каждые 30 секунд
}

function stopHeartbeat() {
    if (heartbeatInterval) {
        clearInterval(heartbeatInterval);
        heartbeatInterval = null;
    }
}
// Обновление статуса пользователя в интерфейсе
function updateUserOnlineStatus(userId, isOnline) {
    console.log(`🟢 Обновление статуса пользователя ${userId}: ${isOnline ? 'онлайн' : 'офлайн'}`);

    // Обновляем статус в списке диалогов
    const dialogElement = document.querySelector(`.dialog-item[data-user-id="${userId}"]`);
    if (dialogElement) {
        const statusDot = dialogElement.querySelector('.online-dot');
        if (statusDot) {
            statusDot.style.background = isOnline ? '#28a745' : '#6c757d';
            console.log(`   ✅ Статус диалога обновлён: ${isOnline ? 'зелёный' : 'серый'}`);
        }
    }

    // Обновляем статус в открытом чате
    if (currentChatUserId === userId) {
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

// ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

function isSameDay(date1, date2) {
    const d1 = new Date(date1);
    const d2 = new Date(date2);
    d1.setHours(0, 0, 0, 0);
    d2.setHours(0, 0, 0, 0);
    return d1.getTime() === d2.getTime();
}

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
        dateText = date.toLocaleDateString('ru-RU', {
            day: 'numeric',
            month: 'long',
            year: date.getFullYear() !== today.getFullYear() ? 'numeric' : undefined
        });
    }

    return `
        <div class="date-separator" data-date="${date.toISOString()}"
             style="display: flex; justify-content: center; margin: 15px 0;">
            <span style="background: rgba(0,0,0,0.05); padding: 5px 15px; border-radius: 20px; font-size: 12px; color: #6c757d;">
                ${dateText}
            </span>
        </div>
    `;
}

// Запуск при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(() => {
        const userId = getCurrentUserId();
        if (userId) {
            initWebSocket();
            // Обновляем бейджи каждые 30 секунд как запасной вариант
            setInterval(updateBadgesFromServer, 30000);
        }
    }, 100);
});

// Переподключение при возвращении на страницу
document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible' && (!socket || socket.readyState !== WebSocket.OPEN)) {
        initWebSocket();
    }
});

window.debugAuth = function() {
    console.log('=== ДИАГНОСТИКА АВТОРИЗАЦИИ ===');
    console.log('Cookies:', document.cookie);
    console.log('user-data:', document.getElementById('user-data')?.dataset);
    console.log('window.currentUser:', window.currentUser);
    console.log('socket state:', socket?.readyState);

    fetch('/api/online-users', { credentials: 'same-origin' })
        .then(res => res.json())
        .then(data => console.log('Онлайн пользователи:', data))
        .catch(err => console.error('Ошибка:', err));
};


// Получить последнюю дату в чате
function getLastMessageDate() {
    const messagesContainer = document.getElementById('chatMessages');
    if (!messagesContainer) return null;

    const separators = messagesContainer.querySelectorAll('.date-separator');
    if (separators.length > 0) {
        const lastSeparator = separators[separators.length - 1];
        return new Date(lastSeparator.dataset.date);
    }

    // Если нет разделителей, ищем последнее сообщение
    const messages = messagesContainer.children;
    for (let i = messages.length - 1; i >= 0; i--) {
        if (!messages[i].classList?.contains('date-separator')) {
            // Извлекаем дату из сообщения (если есть)
            const timeElement = messages[i].querySelector('.message-time');
            if (timeElement && timeElement.dataset.datetime) {
                return new Date(timeElement.dataset.datetime);
            }
        }
    }

    return null;
}

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

            try {
                // Проверяем права
                const dashboardBtn = document.querySelector('.dashboard-btn');
                if (!dashboardBtn) {
                    showNotification('У вас нет прав для создания объектов', 'error');
                    window._submitting = false;
                    return;
                }

                // Собираем данные формы
                const formData = new FormData();

                // Основные поля
                formData.append('title', document.getElementById('propTitle')?.value.trim() || '');
                formData.append('description', document.getElementById('propDescription')?.value.trim() || '');
                formData.append('address', document.getElementById('propAddress')?.value.trim() || '');
                formData.append('city', document.getElementById('propCity')?.value.trim() || '');
                formData.append('property_type', document.getElementById('propType')?.value || 'apartment');
                formData.append('area', document.getElementById('propArea')?.value || '0');
                formData.append('rooms', document.getElementById('propRooms')?.value || '0');
                formData.append('price', document.getElementById('propPrice')?.value || '0');
                formData.append('interval_pay', document.getElementById('propInterval')?.value || 'month');

                // Проверка обязательных полей
                const requiredFields = ['title', 'address', 'city', 'property_type', 'area', 'price', 'interval_pay'];
                for (let field of requiredFields) {
                    if (!formData.get(field)) {
                        showNotification(`Заполните поле ${field}`, 'error');
                        window._submitting = false;
                        return;
                    }
                }

                // Добавляем фотографии
                if (window.uploadedFiles && window.uploadedFiles.length > 0) {
                    window.uploadedFiles.forEach(file => {
                        formData.append('photos', file);
                    });
                }

                const propertyId = propertyEditForm.dataset.propertyId;
                const isEditing = !!propertyId;
                const url = isEditing ? `/api/properties/${propertyId}` : '/api/properties';

                console.log(`📤 ${isEditing ? 'Обновление' : 'Создание'} объекта...`);

                const response = await fetch(url, {
                    method: isEditing ? 'PUT' : 'POST',
                    body: formData,
                    credentials: 'same-origin'
                });

                const responseText = await response.text();
                console.log('📥 Ответ сервера:', responseText);

                if (!response.ok) {
                    let errorMsg = 'Ошибка сохранения';
                    try {
                        const err = JSON.parse(responseText);
                        errorMsg = err.detail || err.message || JSON.stringify(err);
                    } catch (e) {
                        errorMsg = responseText || errorMsg;
                    }
                    throw new Error(errorMsg);
                }

                const result = JSON.parse(responseText);

                showNotification(isEditing ? 'Объект обновлён' : 'Объект создан', 'success');

                // Очищаем форму
                propertyEditForm.reset();
                delete propertyEditForm.dataset.propertyId;
                window.uploadedFiles = [];
                updatePhotoPreview();

                closeModal('propertyEditModal');

                // Обновляем список объектов, если он открыт
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

    if (window.currentUser?.id) {
        // Первоначальная загрузка
        fetch('/api/my/dialogs', { credentials: 'same-origin' })
            .then(res => res.json())
            .then(dialogs => updateBadges(dialogs))
            .catch(err => console.error('Ошибка загрузки диалогов:', err));

        startNotificationsRefresh();
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

// ==================== УВЕДОМЛЕНИЯ И СООБЩЕНИЯ ====================

let notificationsRefreshInterval = null;

// Переключение дропдауна уведомлений
function toggleNotifications() {
    const dropdown = document.getElementById('notificationsDropdown');
    const messagesDropdown = document.getElementById('messagesDropdown');

    if (messagesDropdown) messagesDropdown.classList.remove('show');

    if (dropdown.classList.contains('show')) {
        dropdown.classList.remove('show');
    } else {
        dropdown.classList.add('show');
        loadSystemNotifications(); // Загружаем только системные уведомления
    }
}

// Переключение дропдауна сообщений
function toggleMessages() {
    const dropdown = document.getElementById('messagesDropdown');
    const notificationsDropdown = document.getElementById('notificationsDropdown');

    if (notificationsDropdown) notificationsDropdown.classList.remove('show');

    if (dropdown.classList.contains('show')) {
        dropdown.classList.remove('show');
    } else {
        dropdown.classList.add('show');
        loadRecentMessages(); // Загружаем последние личные сообщения
    }
}

// Переключение ответов FAQ
function toggleFaqAnswer(element) {
    const answer = element.nextElementSibling;
    const arrow = element.querySelector('span');

    if (answer.style.display === 'none' || !answer.style.display) {
        answer.style.display = 'block';
        if (arrow) arrow.innerHTML = '▲';
    } else {
        answer.style.display = 'none';
        if (arrow) arrow.innerHTML = '▼';
    }
}

// Загрузить уведомления (только системные для текущего пользователя)
async function loadNotifications() {
    try {
        const response = await fetch('/api/notifications', { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки уведомлений');

        const notifications = await response.json();
        console.log('Уведомления:', notifications);

        const container = document.getElementById('notificationsList');
        if (!container) return;

        if (notifications.length === 0) {
            container.innerHTML = '<div class="notification-item">Нет новых уведомлений</div>';
            updateNotificationsBadge([]);
            return;
        }

        // Группируем уведомления по содержанию, чтобы избежать дубликатов
        const uniqueNotifications = [];
        const seen = new Set();

        notifications.forEach(n => {
            const contentKey = n.content.replace(/\s+/g, ' ').trim();
            if (!seen.has(contentKey)) {
                seen.add(contentKey);
                uniqueNotifications.push(n);
            }
        });

        let html = '';
        uniqueNotifications.forEach(n => {
            const date = new Date(n.created_at);
            const timeStr = date.toLocaleString('ru-RU', {
                hour: '2-digit',
                minute: '2-digit',
                day: '2-digit',
                month: '2-digit'
            }).replace(',', '');

            // Определяем иконку и заголовок по содержимому
            let icon = '📋';
            let title = '';
            let description = n.content;
            let bgColor = '#f8f9fa';

            // Извлекаем заголовок из текста (то, что в **)
            const titleMatch = n.content.match(/\*\*(.*?)\*\*/);
            if (titleMatch) {
                title = titleMatch[1];
                description = n.content.replace(titleMatch[0], '').trim();
            }

            // Определяем иконку по заголовку или содержимому
            if (title.includes('одобрена') || title.includes('approved') || n.content.includes('одобрена')) {
                icon = '✅';
                bgColor = '#d4edda';
            } else if (title.includes('отклонена') || title.includes('rejected') || n.content.includes('отклонена')) {
                icon = '❌';
                bgColor = '#f8d7da';
            } else if (title.includes('подписал') || n.content.includes('подписал')) {
                icon = '✍️';
                bgColor = '#cce5ff';
            } else if (title.includes('Новая заявка') || n.content.includes('Новая заявка')) {
                icon = '🏠';
                bgColor = '#fff3cd';
            } else if (title.includes('Договор отменён') || n.content.includes('Договор отменён')) {
                icon = '🚫';
                bgColor = '#f8d7da';
            }

            html += `
                <div class="notification-item ${n.is_read ? '' : 'unread'}"
                     onclick="markNotificationRead(${n.id})"
                     style="background-color: ${bgColor}20; border-left: 3px solid ${bgColor.replace('#', '')}">

                    <!-- Верхняя строка с иконкой и временем -->
                    <div class="notification-header">
                        <span class="notification-icon">${icon}</span>
                        ${title ? `<div class="notification-title"><strong>${title}</strong></div>` : ''}
                        <span class="notification-time">${timeStr}</span>
                    </div>

                    <!-- Заголовок (жирный текст) - на одной строке с иконкой по сути, но с отступом -->


                    <!-- Описание (остальной текст) -->
                    ${description ? `<div class="notification-description">${description}</div>` : ''}

                    ${n.is_read ? '' : '<span class="unread-dot"></span>'}
                </div>
            `;
        });

        container.innerHTML = html;
        updateNotificationsBadge(notifications);

    } catch (error) {
        console.error('Ошибка загрузки уведомлений:', error);
    }
}

// Отметить уведомление как прочитанное (можно вызвать при клике)
async function markNotificationRead(notificationId) {
    try {
        await fetch(`/api/notifications/${notificationId}/read`, { method: 'POST', credentials: 'same-origin' });
        loadNotifications(); // обновить список
        updateBadgesFromServer();
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

// Обновить счётчик уведомлений с поддержкой +9
function updateNotificationsBadge(notifications) {
    const unreadCount = notifications.filter(n => !n.is_read).length;
    const badge = document.getElementById('notificationsBadge');
    if (unreadCount > 0) {
        badge.textContent = unreadCount > 9 ? '+9' : unreadCount;
        badge.style.display = 'flex';
    } else {
        badge.style.display = 'none';
    }
}
// Обновление счетчиков уведомлений и сообщений
async function updateNotificationBadges() {
    if (!window.currentUser?.id) return;

    try {
        // Получаем количество непрочитанных системных уведомлений
        const notifResponse = await fetch('/api/notifications/unread-count', { credentials: 'same-origin' });
        if (notifResponse.ok) {
            const notifData = await notifResponse.json();
            updateBadge('notificationsBadge', notifData.count);
        }

        // Получаем количество непрочитанных личных сообщений
        const msgResponse = await fetch('/api/messages/unread-count', { credentials: 'same-origin' });
        if (msgResponse.ok) {
            const msgData = await msgResponse.json();
            updateBadge('messagesBadge', msgData.count);
        }
    } catch (error) {
        console.error('Ошибка обновления бейджей:', error);
    }
}



// Получение количества НЕПРОЧИТАННЫХ СИСТЕМНЫХ УВЕДОМЛЕНИЙ (from_user_id IS NULL)
async function getSystemNotificationsCount() {
    try {
        const response = await fetch('/api/notifications/unread-count', { credentials: 'same-origin' });
        if (response.ok) {
            const data = await response.json();
            return data.count;
        }
        return 0;
    } catch (error) {
        console.error('Ошибка получения количества уведомлений:', error);
        return 0;
    }
}


// Получение количества непрочитанных ЛИЧНЫХ СООБЩЕНИЙ (from_user_id IS NOT NULL)
async function getUnreadMessagesCount() {
    try {
        const response = await fetch('/api/messages/unread-count', { credentials: 'same-origin' });
        if (response.ok) {
            const data = await response.json();
            return data.count;
        }
        return 0;
    } catch (error) {
        console.error('Ошибка получения количества сообщений:', error);
        return 0;
    }
}

// Загрузка только системных уведомлений (from_user_id IS NULL)
async function loadSystemNotifications() {
    try {
        const response = await fetch('/api/notifications', { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки уведомлений');

        const notifications = await response.json();
        console.log('Системные уведомления:', notifications);

        const container = document.getElementById('notificationsList');
        if (!container) return;

        if (notifications.length === 0) {
            container.innerHTML = '<div class="notification-item">Нет новых уведомлений</div>';
            updateBadge('notificationsBadge', 0);
            return;
        }

        const unreadCount = notifications.filter(n => !n.is_read).length;
        updateBadge('notificationsBadge', unreadCount, true);

        let html = '';
        notifications.forEach(n => {
            const date = new Date(n.created_at);
            const timeStr = date.toLocaleString('ru-RU', {
                hour: '2-digit',
                minute: '2-digit',
                day: '2-digit',
                month: '2-digit'
            }).replace(',', '');

            // Определяем иконку
            let icon = '📋';
            if (n.content.includes('одобрена')) icon = '✅';
            else if (n.content.includes('отклонена')) icon = '❌';
            else if (n.content.includes('подписал')) icon = '✍️';
            else if (n.content.includes('Новая заявка')) icon = '🏠';
            else if (n.content.includes('Договор отменён')) icon = '🚫';

            // Извлекаем заголовок (то, что в **)
            let title = '';
            let description = n.content;
            const titleMatch = n.content.match(/\*\*(.*?)\*\*/);
            if (titleMatch) {
                title = titleMatch[1];
                description = n.content.replace(titleMatch[0], '').trim();
            }

            html += `
                <div class="notification-item ${n.is_read ? '' : 'unread'}" onclick="markNotificationRead(${n.id})">
                    <div class="notification-header">
                        <span class="notification-icon">${icon}</span>
                        ${title ? `<div class="notification-title"><strong>${title}</strong></div>` : ''}
                        <span class="notification-time">${timeStr}</span>
                    </div>

                    ${description ? `<div class="notification-description">${description}</div>` : ''}
                    ${n.is_read ? '' : '<span class="unread-dot"></span>'}
                </div>
            `;
        });
        container.innerHTML = html;

    } catch (error) {
        console.error('Ошибка загрузки уведомлений:', error);
    }
}

// Загрузка последних сообщений (личные)
async function loadRecentMessages() {
    try {
        const response = await fetch('/api/my/dialogs', { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки');

        const dialogs = await response.json();

        // Считаем только непрочитанные ЛИЧНЫЕ сообщения
        const unreadMessagesCount = dialogs.reduce((sum, d) => sum + (d.unread || 0), 0);
        updateBadge('messagesBadge', unreadMessagesCount, true);

        const container = document.getElementById('messagesDropdownList');
        if (!container) return;

        if (dialogs.length === 0) {
            container.innerHTML = '<div class="message-item loading">Нет сообщений</div>';
            return;
        }

        const recentDialogs = dialogs.slice(0, 5);
        let html = '';
        recentDialogs.forEach(dialog => {
            const time = dialog.last_time ? new Date(dialog.last_time).toLocaleTimeString('ru-RU', {
                hour: '2-digit',
                minute: '2-digit'
            }) : '';

            html += `
                <div class="message-item ${dialog.unread > 0 ? 'unread' : ''}" onclick="openChat(${dialog.user_id}); toggleMessages()">
                    <div class="message-sender">${dialog.user_name}</div>
                    <div class="message-preview">${dialog.last_message || '...'}</div>
                    <div class="message-time">${time}</div>
                </div>
            `;
        });
        container.innerHTML = html;

    } catch (error) {
        console.error('Ошибка загрузки сообщений:', error);
    }
}

// Добавление нового уведомления в список
function addNotificationToList(notification) {
    const container = document.getElementById('notificationsList');
    if (!container) return;

    // Проверяем, есть ли уже такое уведомление (за последние 2 секунды)
    const existingItems = container.querySelectorAll('.notification-item');
    for (let item of existingItems) {
        const text = item.querySelector('.notification-text')?.textContent || '';
        if (text.includes(notification.content.substring(0, 20))) {
            return; // Дубликат, не добавляем
        }
    }

    const date = new Date(notification.created_at);
    const timeStr = date.toLocaleString('ru-RU', {
        hour: '2-digit',
        minute: '2-digit',
        day: '2-digit',
        month: '2-digit'
    }).replace(',', '');

    // Определяем иконку
    let icon = '📋';
    let bgColor = '#f8f9fa';

    if (notification.content.includes('одобрена')) {
        icon = '✅';
        bgColor = '#d4edda';
    } else if (notification.content.includes('отклонена')) {
        icon = '❌';
        bgColor = '#f8d7da';
    } else if (notification.content.includes('подписал')) {
        icon = '✍️';
        bgColor = '#cce5ff';
    } else if (notification.content.includes('Новая заявка')) {
        icon = '🏠';
        bgColor = '#fff3cd';
    } else if (notification.content.includes('Договор отменён')) {
        icon = '🚫';
        bgColor = '#f8d7da';
    } else if (notification.content.includes('Договор создан')) {
        icon = '📄';
        bgColor = '#d4edda';
    }

    // Извлекаем заголовок
    let title = '';
    let description = notification.content;
    const titleMatch = notification.content.match(/\*\*(.*?)\*\*/);
    if (titleMatch) {
        title = titleMatch[1];
        description = notification.content.replace(titleMatch[0], '').trim();
    }

    const newItem = document.createElement('div');
    newItem.className = `notification-item unread`;
    newItem.setAttribute('onclick', `markNotificationRead(${notification.id})`);
    newItem.style.backgroundColor = `${bgColor}20`;
    newItem.style.borderLeft = `3px solid ${bgColor.replace('#', '')}`;
    newItem.style.animation = 'fadeIn 0.3s';

    newItem.innerHTML = `
        <div class="notification-header">
            <span class="notification-icon">${icon}${title ? `<div class="notification-title"><strong>${title}</strong></div>` : ''}</span>

            <span class="notification-time">${timeStr}</span>
        </div>

        ${description ? `<div class="notification-description">${description}</div>` : ''}
        <span class="unread-dot"></span>
    `;

    // Добавляем в начало списка
    container.insertBefore(newItem, container.firstChild);

    // Если список длинный, удаляем последний элемент
    if (container.children.length > 50) {
        container.removeChild(container.lastChild);
    }
}

// Запустить периодическое обновление бейджей
function startBadgeRefresh() {
    if (window.badgeRefreshInterval) {
        clearInterval(window.badgeRefreshInterval);
    }

    // Обновляем каждые 10 секунд как запасной вариант
    window.badgeRefreshInterval = setInterval(() => {
        if (window.currentUser?.id) {
            updateNotificationBadges();
        }
    }, 10000);
}

// Остановить обновление
function stopBadgeRefresh() {
    if (window.badgeRefreshInterval) {
        clearInterval(window.badgeRefreshInterval);
        window.badgeRefreshInterval = null;
    }
}
// ==================== ФУНКЦИИ ДЛЯ РУКОВОДСТВА ====================

function switchGuideTab(tabName) {
    console.log('Переключение вкладки руководства на:', tabName);

    // Получаем все вкладки и контент
    const tabs = document.querySelectorAll('.tab-btn');
    const contents = document.querySelectorAll('.guide-tab-content');

    // Анимация исчезновения
    const currentContent = document.querySelector('.guide-tab-content[style*="display: block"]');
    if (currentContent) {
        currentContent.style.animation = 'fadeOut 0.2s ease-out';
        setTimeout(() => {
            currentContent.style.display = 'none';
        }, 150);
    }

    // Показываем новую вкладку с анимацией
    setTimeout(() => {
        const selectedTab = document.getElementById('guideTab-' + tabName);
        if (selectedTab) {
            selectedTab.style.display = 'block';
            selectedTab.style.animation = 'fadeIn 0.3s ease-out';
        }
    }, 150);

    // Обновляем стили кнопок
    tabs.forEach(btn => {
        btn.classList.remove('active');
    });

    // Активируем текущую кнопку
    const activeBtn = document.querySelector(`.tab-btn[data-tab="${tabName}"]`);
    if (activeBtn) {
        activeBtn.classList.add('active');
    }
}

const style = document.createElement('style');
style.textContent = `
    @keyframes fadeOut {
        from { opacity: 1; transform: translateX(0); }
        to { opacity: 0; transform: translateX(-20px); }
    }
`;
document.head.appendChild(style);

// Инициализация вкладок при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    // Активировать вкладку "Арендатор" по умолчанию
    const tenantTab = document.querySelector('.tab-btn[data-tab="tenant"]');
    if (tenantTab) {
        setTimeout(() => {
            switchGuideTab('tenant');
        }, 100);
    }
});

// Добавьте в DOMContentLoaded или в существующий код
document.addEventListener('DOMContentLoaded', function() {
    const periodSelect = document.getElementById('statsPeriod');
    if (periodSelect) {
        periodSelect.addEventListener('change', function() {
            loadAgentStats();
        });
    }
});

// Отметить все уведомления как прочитанные
async function markAllNotificationsRead() {
    try {
        const response = await fetch('/api/notifications/read-all', {
            method: 'POST',
            credentials: 'same-origin'
        });

        if (response.ok) {
            // Обновляем список
            await loadNotifications();
            await updateBadgesFromServer();
            showNotification('Все уведомления отмечены как прочитанные', 'success');
        }
    } catch (error) {
        console.error('Ошибка:', error);
    }
}

// Периодическое обновление уведомлений
let notificationsInterval = null;

function startNotificationsRefresh() {
    if (notificationsInterval) clearInterval(notificationsInterval);

    notificationsInterval = setInterval(async () => {
        if (window.currentUser?.id) {
            // Обновляем только системные уведомления
            await loadSystemNotifications();

            // Обновляем счетчик личных сообщений
            const unreadCount = await getUnreadMessagesCount();
            updateBadge('messagesBadge', unreadCount);
        }
    }, 15000); // Каждые 15 секунд
}

// ==================== АДМИН-ФУНКЦИИ ====================

// Переменные для пагинации
let adminUsersCurrentPage = 1;
let adminUsersTotalPages = 1;

// Показать модалку со списком пользователей
function showAdminUsers() {
    console.log('showAdminUsers вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');

    // Сбрасываем фильтры
    document.getElementById('adminUserSearch').value = '';
    document.getElementById('adminUserType').value = '';

    // Загружаем пользователей
    loadAdminUsers(1);

    // Открываем модалку
    openModal('adminUsersModal');
}

// Загрузить список пользователей
async function loadAdminUsers(page = 1) {
    adminUsersCurrentPage = page;

    const search = document.getElementById('adminUserSearch').value;
    const userType = document.getElementById('adminUserType').value;

    let url = `/api/admin/users?page=${page}&per_page=10`;
    if (search) url += `&search=${encodeURIComponent(search)}`;
    if (userType) url += `&user_type=${encodeURIComponent(userType)}`;

    try {
        const response = await fetch(url, { credentials: 'same-origin' });
        if (!response.ok) {
            if (response.status === 403) {
                showNotification('У вас нет прав для просмотра этой страницы', 'error');
                closeModal('adminUsersModal');
                return;
            }
            throw new Error('Ошибка загрузки');
        }

        const data = await response.json();
        adminUsersTotalPages = data.total_pages;

        const tbody = document.getElementById('adminUsersTableBody');

        if (data.users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" style="text-align: center; padding: 40px; color: #6c757d;">Пользователи не найдены</td></tr>';
        } else {
            let html = '';
            data.users.forEach(user => {
                const statusClass = user.is_active ? 'status-active' : 'status-inactive';
                const statusText = user.is_active ? 'Активен' : 'Заблокирован';
                const statusBg = user.is_active ? '#d4edda' : '#f8d7da';
                const statusColor = user.is_active ? '#155724' : '#721c24';

                // Аватар
                let avatarHtml = '';
                if (user.avatar_url) {
                    avatarHtml = `<img src="${user.avatar_url}" style="width: 40px; height: 40px; border-radius: 50%; object-fit: cover;">`;
                } else {
                    const initials = user.full_name ?
                        user.full_name.split(' ').map(n => n[0]).join('').toUpperCase().substring(0, 2) :
                        user.email[0].toUpperCase();
                    avatarHtml = `<div style="width: 40px; height: 40px; border-radius: 50%; background: linear-gradient(135deg, #007bff, #0056b3); color: white; display: flex; align-items: center; justify-content: center; font-weight: 600; font-size: 16px;">${initials}</div>`;
                }

                html += `
                    <tr style="border-bottom: 1px solid #e9ecef;">
                        <td style="padding: 12px;">${user.id}</td>
                        <td style="padding: 12px;">${avatarHtml}</td>
                        <td style="padding: 12px; font-weight: 500;">${user.full_name || '—'}</td>
                        <td style="padding: 12px;">${user.email}</td>
                        <td style="padding: 12px;">${getUserTypeName(user.user_type)}</td>
                        <td style="padding: 12px;">
                            <span style="display: inline-block; padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 500; background: ${statusBg}; color: ${statusColor};">
                                ${statusText}
                            </span>
                        </td>
                        <td style="padding: 12px;">${formatDate(user.created_at)}</td>
                        <td style="padding: 12px;">
                            <div style="display: flex; gap: 8px;">
                                <button class="btn-info" onclick="showAdminUserDetail(${user.id})" style="padding: 5px 10px; background: #17a2b8; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 12px;">
                                    👁️ Подробнее
                                </button>

                            </div>
                        </td>
                    </tr>
                `;
            });
            tbody.innerHTML = html;
        }

        renderAdminUsersPagination();

    } catch (error) {
        console.error('Ошибка:', error);
        document.getElementById('adminUsersTableBody').innerHTML = '<tr><td colspan="8" style="text-align: center; padding: 40px; color: #6c757d;">Ошибка загрузки</td></tr>';
    }
}

// Функция для получения названия типа пользователя
function getUserTypeName(type) {
    const types = {
        'tenant': '👤 Арендатор',
        'owner': '🏠 Собственник',
        'agent': '📋 Агент',
        'admin': '⚙️ Админ'
    };
    return types[type] || type;
}

// Форматирование даты
function formatDate(dateStr) {
    if (!dateStr) return '—';
    const date = new Date(dateStr);
    return date.toLocaleDateString('ru-RU', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Рендер пагинации
function renderAdminUsersPagination() {
    const pagination = document.getElementById('adminUsersPagination');
    if (!pagination) return;

    if (adminUsersTotalPages <= 1) {
        pagination.innerHTML = '';
        return;
    }

    let html = '';

    // Кнопка "Предыдущая"
    html += `<button class="page-btn" ${adminUsersCurrentPage === 1 ? 'disabled' : ''} onclick="loadAdminUsers(${adminUsersCurrentPage - 1})">←</button>`;

    // Номера страниц
    for (let i = 1; i <= adminUsersTotalPages; i++) {
        if (i === 1 || i === adminUsersTotalPages || (i >= adminUsersCurrentPage - 2 && i <= adminUsersCurrentPage + 2)) {
            html += `<button class="page-btn ${i === adminUsersCurrentPage ? 'active' : ''}" onclick="loadAdminUsers(${i})">${i}</button>`;
        } else if (i === adminUsersCurrentPage - 3 || i === adminUsersCurrentPage + 3) {
            html += `<span class="page-dots">...</span>`;
        }
    }

    // Кнопка "Следующая"
    html += `<button class="page-btn" ${adminUsersCurrentPage === adminUsersTotalPages ? 'disabled' : ''} onclick="loadAdminUsers(${adminUsersCurrentPage + 1})">→</button>`;

    pagination.innerHTML = html;
}

// Сброс фильтров
function resetAdminUserFilters() {
    document.getElementById('adminUserSearch').value = '';
    document.getElementById('adminUserType').value = '';
    loadAdminUsers(1);
}

// Показать детали пользователя
async function showAdminUserDetail(userId) {
    try {
        // Загружаем данные пользователя
        const response = await fetch(`/api/user/${userId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки');

        const user = await response.json();

        // Загружаем профиль этого же пользователя для получения contact_info
        let contactInfo = {};
        let isActive = true;
        let userType = user.user_type;

        try {
            const adminResponse = await fetch(`/api/admin/users/${userId}`, { credentials: 'same-origin' });
            if (adminResponse.ok) {
                const adminData = await adminResponse.json();
                contactInfo = adminData.contact_info || {};
                isActive = adminData.is_active;
            } else {
                contactInfo = user.contact_info || {};
                isActive = true;
            }
        } catch (e) {
            console.warn('Не удалось получить дополнительные данные', e);
            contactInfo = user.contact_info || {};
            isActive = true;
        }

        const statusClass = user.is_online ? 'status-active' : 'status-inactive';
        const statusText = user.is_online ? 'Онлайн' : 'Не в сети';
        const statusBg = user.is_online ? '#d4edda' : '#f8d7da';
        const statusColor = user.is_online ? '#155724' : '#721c24';

        const content = document.getElementById('adminUserDetailContent');
        content.innerHTML = `
            <div style="display: flex; align-items: center; gap: 20px; margin-bottom: 20px; padding-bottom: 15px; border-bottom: 1px solid #e9ecef;">
                <div style="width: 80px; height: 80px; border-radius: 50%; overflow: hidden; background: linear-gradient(135deg, #007bff, #0056b3); flex-shrink: 0;">
                    ${user.avatar_url ?
                        `<img src="${user.avatar_url}" style="width: 100%; height: 100%; object-fit: cover;">` :
                        `<div style="width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; color: white; font-size: 32px; font-weight: 600;">${user.full_name ? user.full_name[0].toUpperCase() : user.email[0].toUpperCase()}</div>`
                    }
                </div>
                <div style="flex: 1;">
                    <h3 style="margin: 0 0 5px 0; font-size: 20px;">${user.full_name || 'Без имени'}</h3>
                    <p style="margin: 0; color: #6c757d; font-size: 14px;">${user.email}</p>
                </div>
            </div>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                <div style="background: #f8f9fa; padding: 12px; border-radius: 8px;">
                    <div style="font-size: 11px; color: #6c757d; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px;">ID пользователя</div>
                    <div style="font-weight: 600; font-size: 16px;">${user.user_id}</div>
                </div>
                <div style="background: #f8f9fa; padding: 12px; border-radius: 8px;">
                    <div style="font-size: 11px; color: #6c757d; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px;">Тип</div>
                    <div style="font-weight: 600; font-size: 16px;">${getUserTypeName(user.user_type)}</div>
                </div>
                <div style="background: #f8f9fa; padding: 12px; border-radius: 8px;">
                    <div style="font-size: 11px; color: #6c757d; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px;">Статус</div>
                    <div><span style="display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; background: ${statusBg}; color: ${statusColor};">${statusText}</span></div>
                </div>
                <div style="background: #f8f9fa; padding: 12px; border-radius: 8px;">
                    <div style="font-size: 11px; color: #6c757d; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px;">Телефон</div>
                    <div style="font-weight: 500;">${contactInfo.phone || '—'}</div>
                </div>
                <div style="background: #f8f9fa; padding: 12px; border-radius: 8px;">
                    <div style="font-size: 11px; color: #6c757d; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px;">Город</div>
                    <div style="font-weight: 500;">${contactInfo.city || '—'}</div>
                </div>
                <div style="background: #f8f9fa; padding: 12px; border-radius: 8px;">
                    <div style="font-size: 11px; color: #6c757d; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px;">Дата рождения</div>
                    <div style="font-weight: 500;">${contactInfo.birth_date ? new Date(contactInfo.birth_date).toLocaleDateString('ru-RU') : '—'}</div>
                </div>
            </div>

            ${(contactInfo.passport || contactInfo.inn) ? `
            <div style="margin-top: 15px; background: #f8f9fa; padding: 15px; border-radius: 8px;">
                <h4 style="margin: 0 0 10px 0; font-size: 14px; color: #495057;">Документы</h4>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                    ${contactInfo.passport ? `<div><div style="font-size: 11px; color: #6c757d;">Паспорт</div><div style="font-weight: 500;">${contactInfo.passport}</div></div>` : ''}
                    ${contactInfo.inn ? `<div><div style="font-size: 11px; color: #6c757d;">ИНН</div><div style="font-weight: 500;">${contactInfo.inn}</div></div>` : ''}
                </div>
            </div>
            ` : ''}

            ${contactInfo.block_reason ? `
            <div style="margin-top: 15px; background: #f8d7da; padding: 15px; border-radius: 8px; border-left: 4px solid #dc3545;">
                <h4 style="margin: 0 0 8px 0; font-size: 14px; color: #721c24;">📋 Информация о блокировке</h4>
                <div style="font-size: 13px;">
                    <div><strong>Причина:</strong> ${contactInfo.block_reason}</div>
                    <div><strong>Срок:</strong> ${contactInfo.block_duration === '7' ? '7 дней' : contactInfo.block_duration === '30' ? '30 дней' : 'Навсегда'}</div>
                    ${contactInfo.block_comment ? `<div><strong>Комментарий:</strong> ${contactInfo.block_comment}</div>` : ''}
                    <div><strong>Дата:</strong> ${contactInfo.blocked_at ? new Date(contactInfo.blocked_at).toLocaleString('ru-RU') : '—'}</div>
                </div>
            </div>
            ` : ''}
        `;

        // ===== КНОПКА НАЗНАЧЕНИЯ АГЕНТА =====
        const agentBtn = document.getElementById('adminUserDetailAgentBtn');
        if (agentBtn) {
            if (userType === 'agent') {
                agentBtn.textContent = '🚫 Снять роль агента';
                agentBtn.className = 'btn-warning';
                agentBtn.style.background = '#ffc107';
                agentBtn.style.color = '#212529';
                agentBtn.onclick = function() {
                    toggleAgentRole(userId, true); // true = снять роль
                };
            } else if (userType !== 'admin') {
                agentBtn.textContent = '👤 Назначить агентом';
                agentBtn.className = 'btn-info';
                agentBtn.style.background = '#17a2b8';
                agentBtn.style.color = 'white';
                agentBtn.onclick = function() {
                    toggleAgentRole(userId, false); // false = назначить
                };
            } else {
                agentBtn.style.display = 'none';
            }
        }

        // ===== КНОПКА БЛОКИРОВКИ =====
        const blockBtn = document.getElementById('adminUserDetailBlockBtn');
        if (blockBtn) {
            if (isActive) {
                blockBtn.textContent = '🔒 Заблокировать';
                blockBtn.className = 'btn-warning';
                blockBtn.onclick = function() {
                    showBlockUserModal(userId, user.full_name, user.email);
                };
            } else {
                blockBtn.textContent = '🔓 Разблокировать';
                blockBtn.className = 'btn-success';
                blockBtn.onclick = function() {
                    confirmUnblockUser(userId);
                };
            }
        }

        openModal('adminUserDetailModal');

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка загрузки данных пользователя', 'error');
    }
}


// Переключатель блокировки пользователя
async function toggleUserBlock(userId, isActive) {
    // isActive = true - пользователь активен, false - заблокирован
    const action = isActive ? 'заблокировать' : 'разблокировать';
    if (!confirm(`Вы уверены, что хотите ${action} пользователя?`)) return;

    try {
        const response = await fetch(`/api/admin/users/${userId}/toggle-block`, {
            method: 'PATCH',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка');
        }

        const data = await response.json();
        showNotification(`Пользователь ${data.is_active ? 'разблокирован' : 'заблокирован'}`, 'success');

        // Обновляем кнопку в детальной модалке, если она открыта
        const blockBtn = document.getElementById('adminUserDetailBlockBtn');
        if (blockBtn && blockBtn.getAttribute('data-user-id') == userId) {
            if (data.is_active) {
                blockBtn.textContent = '🔒 Заблокировать';
                blockBtn.className = 'btn-warning';
                blockBtn.style.background = '#ffc107';
                blockBtn.style.color = '#212529';
                blockBtn.setAttribute('data-is-active', 'true');
            } else {
                blockBtn.textContent = '🔓 Разблокировать';
                blockBtn.className = 'btn-success';
                blockBtn.style.background = '#28a745';
                blockBtn.style.color = 'white';
                blockBtn.setAttribute('data-is-active', 'false');
            }
        }

        // Обновляем список пользователей
        loadAdminUsers(adminUsersCurrentPage);

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Функция назначения/снятия роли агента
async function toggleAgentRole(userId, isRemoving) {
    const action = isRemoving ? 'снять роль агента' : 'назначить агентом';
    if (!confirm(`Вы уверены, что хотите ${action} этого пользователя?`)) return;

    try {
        const response = await fetch(`/api/admin/users/${userId}/toggle-agent`, {
            method: 'PATCH',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка');
        }

        const data = await response.json();
        showNotification(`Пользователь ${data.action}`, 'success');

        // Обновляем детальную информацию
        showAdminUserDetail(userId);

        // Обновляем список пользователей
        loadAdminUsers(adminUsersCurrentPage);

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Функция для разблокировки пользователя (без модального окна)
async function confirmUnblockUser(userId) {
    if (!confirm('Вы уверены, что хотите разблокировать этого пользователя?')) return;

    try {
        const response = await fetch(`/api/admin/users/${userId}/toggle-block`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                block_reason: null,
                block_duration: null,
                block_comment: null
            }),
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка разблокировки');
        }

        const data = await response.json();
        showNotification('Пользователь разблокирован', 'success');
        closeModal('adminUserDetailModal');

        // Обновляем список пользователей, если модалка открыта
        if (document.getElementById('adminUsersModal').style.display === 'flex') {
            loadAdminUsers(adminUsersCurrentPage);
        }

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Переменные для хранения данных жалобы
let currentReportPropertyId = null;
let currentReportPropertyTitle = null;

// Открыть модальное окно жалобы
function openReportModal(propertyId) {
    if (!isUserLoggedIn()) {
        showNotification('Необходимо авторизоваться для отправки жалобы', 'warning');
        showLoginModal();
        return;
    }

    currentReportPropertyId = propertyId;

    // Получаем название объекта
    fetch(`/api/property/${propertyId}`, { credentials: 'same-origin' })
        .then(res => res.json())
        .then(data => {
            currentReportPropertyTitle = data.title;
            document.getElementById('reportPropertyTitle').textContent = data.title;
            document.getElementById('reportReason').value = 'fake';
            document.getElementById('reportDescription').value = '';
            // Убираем строку с чекбоксом
            // document.getElementById('reportAnonymous').checked = false;
            openModal('reportPropertyModal');
        })
        .catch(err => {
            console.error('Ошибка загрузки объекта:', err);
            showNotification('Ошибка загрузки данных объекта', 'error');
        });
}

// Отправить жалобу
async function submitReport() {
    const reason = document.getElementById('reportReason').value;
    const description = document.getElementById('reportDescription').value.trim();

    // Валидация
    if (!description) {
        showNotification('Опишите подробнее причину жалобы', 'warning');
        return;
    }

    if (description.length < 10) {
        showNotification('Опишите проблему подробнее (минимум 10 символов)', 'warning');
        return;
    }

    if (!confirm('Отправить жалобу на этот объект? Модераторы рассмотрят её в течение 24 часов.')) {
        return;
    }

    try {
        const response = await fetch('/api/reports', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                property_id: currentReportPropertyId,
                reason: reason,
                description: description,
                is_anonymous: false  // всегда false, так как галочка убрана
            }),
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка отправки жалобы');
        }

        showNotification('Жалоба отправлена. Спасибо за помощь!', 'success');
        closeModal('reportPropertyModal');

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Показать детали объекта для админа
async function showAdminProperty(propertyId) {
    currentPropertyId = propertyId;

    try {
        const response = await fetch(`/api/property/${propertyId}`, { credentials: 'same-origin' });
        if (!response.ok) throw new Error('Ошибка загрузки');

        const prop = await response.json();

        const content = document.getElementById('adminPropertyContent');

        // Формируем галерею фотографий
        let photosHtml = '';
        if (prop.photos && prop.photos.length > 0) {
            photosHtml = '<div style="display: flex; gap: 10px; overflow-x: auto; margin-bottom: 15px; padding-bottom: 5px;">';
            prop.photos.forEach(photo => {
                photosHtml += `
                    <div style="flex-shrink: 0; width: 100px; height: 70px; border-radius: 6px; overflow: hidden; border: 2px solid ${photo.is_main ? '#007bff' : 'transparent'};">
                        <img src="${photo.url}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.src='/resources/placeholder-image.png'">
                    </div>
                `;
            });
            photosHtml += '</div>';
        } else {
            photosHtml = '<div style="margin-bottom: 15px;"><img src="/resources/placeholder-image.png" style="width: 100%; height: 200px; object-fit: cover; border-radius: 8px; background: #f8f9fa;"></div>';
        }

        // Информация о владельце
        const ownerInfo = prop.owner ?
            `<div><strong>Владелец:</strong> ${prop.owner.full_name || 'Не указан'} (${prop.owner.email || 'нет email'})</div>` :
            '<div><strong>Владелец:</strong> Не указан</div>';

        content.innerHTML = `
            ${photosHtml}

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px; background: #f8f9fa; padding: 15px; border-radius: 8px;">
                <div>
                    <div style="font-size: 12px; color: #6c757d;">ID объекта</div>
                    <div style="font-weight: 600; font-size: 16px;">${prop.property_id}</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Статус</div>
                    <div><span class="status-badge ${getStatusClass(prop.status)}" style="display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px;">${getStatusText(prop.status)}</span></div>
                </div>
                <div style="grid-column: span 2;">
                    <div style="font-size: 12px; color: #6c757d;">Название</div>
                    <div style="font-weight: 600; font-size: 18px;">${prop.title}</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Город</div>
                    <div style="font-weight: 500;">${prop.city}</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Адрес</div>
                    <div style="font-weight: 500;">${prop.address}</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Тип</div>
                    <div style="font-weight: 500;">${getPropertyTypeName(prop.property_type)}</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Площадь</div>
                    <div style="font-weight: 500;">${prop.area} м²</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Комнат</div>
                    <div style="font-weight: 500;">${prop.rooms || '—'}</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Цена</div>
                    <div style="font-weight: 700; color: #28a745; font-size: 18px;">${formatPrice(prop.price, prop.interval_pay)}</div>
                </div>
                <div>
                    <div style="font-size: 12px; color: #6c757d;">Создан</div>
                    <div style="font-weight: 500;">${formatDate(prop.created_at)}</div>
                </div>
                <div style="grid-column: span 2;">
                    ${ownerInfo}
                </div>
            </div>

            <div style="margin-top: 15px;">
                <div style="font-weight: 600; margin-bottom: 8px;">Описание</div>
                <div style="background: #f8f9fa; padding: 15px; border-radius: 8px; line-height: 1.6; color: #495057;">
                    ${prop.description || 'Нет описания'}
                </div>
            </div>
        `;

        document.getElementById('adminPropertyTitle').textContent = `Объект №${prop.property_id}`;
        openModal('adminPropertyModal');

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка загрузки объекта', 'error');
    }
}

// Удаление объекта администратором
async function adminDeleteProperty(propertyId) {
    if (!confirm('⚠️ ВНИМАНИЕ! Вы уверены, что хотите удалить этот объект? Это действие необратимо.')) return;

    try {
        const response = await fetch(`/api/admin/properties/${propertyId}`, {
            method: 'DELETE',
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка удаления');
        }

        showNotification('Объект успешно удалён', 'success');
        hidePropertyModal(); // Закрываем модалку

        // Обновляем страницу или список объектов
        setTimeout(() => {
            window.location.reload();
        }, 1500);

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Переменная для хранения ID пользователя для блокировки
let currentBlockUserId = null;
let currentBlockUserName = '';
let currentBlockUserEmail = '';

// Показать модалку блокировки
function showBlockUserModal(userId, userName, userEmail) {
    currentBlockUserId = userId;
    currentBlockUserName = userName;
    currentBlockUserEmail = userEmail;

    const blockModal = document.getElementById('blockUserModal');
    if (blockModal) {
        document.getElementById('blockUserName').textContent = userName;
        document.getElementById('blockUserEmail').textContent = userEmail;

        // Сбрасываем значения
        document.getElementById('blockReason').value = 'fraud';
        document.getElementById('blockDuration').value = '7';
        document.getElementById('blockComment').value = '';

        openModal('blockUserModal');
    } else {
        // Если модального окна нет, показываем простой confirm
        if (confirm('Заблокировать пользователя?')) {
            blockUserWithoutModal(userId);
        }
    }
}

// Подтверждение блокировки
async function confirmBlockUser() {
    const reason = document.getElementById('blockReason').value;
    const duration = document.getElementById('blockDuration').value;
    const comment = document.getElementById('blockComment').value;

    if (!reason) {
        showNotification('Выберите причину блокировки', 'warning');
        return;
    }

    let reasonText = '';
    const reasonsMap = {
        'fraud': 'мошеннические действия',
        'spam': 'рассылка спама',
        'fake_property': 'размещение фальшивых объектов',
        'harassment': 'оскорбления и домогательства',
        'documents': 'подделка документов',
        'multiple_accounts': 'создание нескольких аккаунтов',
        'other': 'другое нарушение'
    };
    reasonText = reasonsMap[reason] || reason;

    let confirmMessage = `Вы действительно хотите заблокировать пользователя?\n\n`;
    confirmMessage += `Пользователь: ${currentBlockUserName}\n`;
    confirmMessage += `Email: ${currentBlockUserEmail}\n`;
    confirmMessage += `Причина: ${reasonText}\n`;
    confirmMessage += `Срок: ${duration === '7' ? '7 дней' : duration === '30' ? '30 дней' : 'Навсегда'}\n`;
    if (comment) confirmMessage += `Комментарий: ${comment}\n`;

    if (!confirm(confirmMessage)) return;

    try {
        const response = await fetch(`/api/admin/users/${currentBlockUserId}/toggle-block`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                block_reason: reason,
                block_duration: duration,
                block_comment: comment
            }),
            credentials: 'same-origin'
        });

        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Ошибка блокировки');
        }

        const data = await response.json();
        showNotification(`Пользователь ${data.is_active ? 'разблокирован' : 'заблокирован'}`, 'success');
        closeModal('blockUserModal');
        closeModal('adminUserDetailModal');

        // Обновляем список пользователей
        loadAdminUsers(adminUsersCurrentPage);

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification(error.message, 'error');
    }
}

// Вспомогательные функции
function getPropertyTypeName(type) {
    const types = {
        'apartment': 'Квартира',
        'house': 'Дом',
        'commercial': 'Коммерческая'
    };
    return types[type] || type;
}

function getStatusClass(status) {
    const classes = {
        'active': 'status-active',
        'draft': 'status-draft',
        'rented': 'status-rented',
        'archived': 'status-archived'
    };
    return classes[status] || 'status-draft';
}

function getStatusText(status) {
    const texts = {
        'active': 'Активно',
        'draft': 'Черновик',
        'rented': 'Сдано',
        'archived': 'В архиве'
    };
    return texts[status] || status;
}

function showAdminProperties() {
    console.log('showAdminProperties вызван');
    document.getElementById('userDropdown')?.classList.remove('show');
    document.getElementById('dashboardDropdown')?.classList.remove('show');
    // Здесь можно открыть модалку со списком объектов или перейти на отдельную страницу
    window.location.href = '/admin/properties'; // или своя логика
}

// Проверка документов для становления собственником
async function checkOwnerDocuments() {
    try {
        const response = await fetch('/api/user/profile', { credentials: 'same-origin' });
        if (!response.ok) return { passport: false, inn: false };

        const user = await response.json();
        const contactInfo = user.contact_info || {};

        const passport = contactInfo.passport && contactInfo.passport.trim().length >= 10;
        const inn = contactInfo.inn && contactInfo.inn.trim().length >= 10;

        return { passport, inn };
    } catch (error) {
        console.error('Ошибка проверки документов:', error);
        return { passport: false, inn: false };
    }
}

// Открыть модальное окно становления собственником
async function openBecomeOwnerModal() {
    // Проверяем документы
    const docs = await checkOwnerDocuments();

    // Обновляем статус документов в модалке
    const passportStatus = document.getElementById('docPassportStatus');
    const innStatus = document.getElementById('docInnStatus');
    const confirmBtn = document.getElementById('confirmBecomeOwnerBtn');

    if (passportStatus) {
        if (docs.passport) {
            passportStatus.innerHTML = '✓ Заполнен';
            passportStatus.style.color = '#28a745';
        } else {
            passportStatus.innerHTML = '✗ Не заполнен';
            passportStatus.style.color = '#dc3545';
        }
    }

    if (innStatus) {
        if (docs.inn) {
            innStatus.innerHTML = '✓ Заполнен';
            innStatus.style.color = '#28a745';
        } else {
            innStatus.innerHTML = '✗ Не заполнен';
            innStatus.style.color = '#dc3545';
        }
    }

    // Если документы заполнены, показываем предупреждение, что можно стать собственником
    const docsCheck = document.getElementById('ownerDocumentsCheck');
    if (docs.passport && docs.inn) {
        docsCheck.innerHTML = `
            <div style="background: #d4edda; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                <p style="margin: 0; color: #155724;">
                    ✅ Паспортные данные и ИНН заполнены. Вы можете стать собственником.
                </p>
            </div>
            <div style="display: flex; gap: 15px; margin-bottom: 20px;">
                <div style="flex: 1;">
                    <div style="font-size: 13px; color: #6c757d; margin-bottom: 5px;">📄 Паспорт</div>
                    <div style="font-weight: 500; color: #28a745;">✓ Заполнен</div>
                </div>
                <div style="flex: 1;">
                    <div style="font-size: 13px; color: #6c757d; margin-bottom: 5px;">🔢 ИНН</div>
                    <div style="font-weight: 500; color: #28a745;">✓ Заполнен</div>
                </div>
            </div>
        `;
        confirmBtn.disabled = false;
    } else {
        docsCheck.innerHTML = `
            <div style="background: #fff3cd; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                <p style="margin: 0; color: #856404;">
                    ⚠️ Для становления собственником необходимо заполнить паспортные данные и ИНН в профиле.
                </p>
            </div>
            <div style="display: flex; gap: 15px; margin-bottom: 20px;">
                <div style="flex: 1;">
                    <div style="font-size: 13px; color: #6c757d; margin-bottom: 5px;">📄 Паспорт</div>
                    <div style="font-weight: 500; color: ${docs.passport ? '#28a745' : '#dc3545'};">${docs.passport ? '✓ Заполнен' : '✗ Не заполнен'}</div>
                </div>
                <div style="flex: 1;">
                    <div style="font-size: 13px; color: #6c757d; margin-bottom: 5px;">🔢 ИНН</div>
                    <div style="font-weight: 500; color: ${docs.inn ? '#28a745' : '#dc3545'};">${docs.inn ? '✓ Заполнен' : '✗ Не заполнен'}</div>
                </div>
            </div>
        `;
        confirmBtn.disabled = true;
    }

    // Добавляем обработчик изменения чекбокса
    const agreementCheckbox = document.getElementById('ownerAgreement');
    if (agreementCheckbox) {
        agreementCheckbox.checked = false;
        agreementCheckbox.onchange = function() {
            confirmBtn.disabled = !(docs.passport && docs.inn && this.checked);
        };
    }

    openModal('becomeOwnerModal');
}

// Подтверждение становления собственником
async function confirmBecomeOwner() {
    const agreementCheckbox = document.getElementById('ownerAgreement');
    if (!agreementCheckbox.checked) {
        showNotification('Необходимо согласиться с положением', 'warning');
        return;
    }

    // Проверяем документы ещё раз
    const docs = await checkOwnerDocuments();
    if (!docs.passport || !docs.inn) {
        showNotification('Необходимо заполнить паспортные данные и ИНН в профиле', 'error');
        closeModal('becomeOwnerModal');
        showProfileModal();
        return;
    }

    if (!confirm('Вы действительно хотите стать собственником? Это действие нельзя отменить.')) return;

    try {
        showNotification('Обработка запроса...', 'info');

        const response = await fetch('/api/user/become-owner', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'same-origin'
        });

        const data = await response.json();

        if (data.success) {
            showNotification('Поздравляем! Теперь вы являетесь собственником!', 'success');
            closeModal('becomeOwnerModal');

            // Обновляем информацию о пользователе
            if (window.currentUser) {
                window.currentUser.type = 'owner';
            }

            // Перезагружаем страницу для обновления интерфейса
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            showNotification(data.message || 'Ошибка при смене роли', 'error');
        }

    } catch (error) {
        console.error('Ошибка:', error);
        showNotification('Ошибка при смене роли', 'error');
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

    const notificationsIcon = document.getElementById('notificationsIcon');
    const messagesIcon = document.getElementById('messagesIcon');
    const notificationsDropdown = document.getElementById('notificationsDropdown');
    const messagesDropdown = document.getElementById('messagesDropdown');

    if (notificationsIcon && !notificationsIcon.contains(event.target)) {
        notificationsDropdown?.classList.remove('show');
    }

    if (messagesIcon && !messagesIcon.contains(event.target)) {
        messagesDropdown?.classList.remove('show');
    }
});


// Автодополнение городов с вежливой паузой через API hh.ru
const cityInput = document.getElementById('city');
const cityDatalist = document.getElementById('citySuggestions');

if (cityInput && cityDatalist) {
    cityInput.addEventListener('input', function() {
        const query = this.value;

        // Используем функцию из hh_api.js
        HH_API.searchCities(query, (cities) => {
            // Очищаем старые подсказки
            cityDatalist.innerHTML = '';

            // Добавляем новые подсказки
            cities.forEach(city => {
                const option = document.createElement('option');
                option.value = city;
                cityDatalist.appendChild(option);
            });
        });
    });
}
document.addEventListener('DOMContentLoaded', () => {
    initCitySelectors();
    validateDocuments();
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

// Существующие функции (которые уже были)
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
window.synchronizeCity = synchronizeCity;
window.uploadAvatar = uploadAvatar;
window.deleteAvatar = deleteAvatar;
window.loadMyApplications = loadMyApplications;
window.showIncomingApplications = showIncomingApplications;
window.showApplicationDetail = showApplicationDetail;
window.cancelApplication = cancelApplication;
window.cancelApplicationFromDetail = cancelApplicationFromDetail;
window.acceptApplication = acceptApplication;
window.rejectApplication = rejectApplication;
window.goToContract = goToContract;
window.closeApplicationDetailAndShowMyApplications = closeApplicationDetailAndShowMyApplications;
window.closeApplicationDetail = closeApplicationDetail;
window.showRespondModal = showRespondModal;
window.loadIncomingApplications = loadIncomingApplications;
window.submitPropertyForm = submitPropertyForm;
window.updatePropertyEditButtonsForEditing = updatePropertyEditButtonsForEditing;
window.goToContractFromApplication = goToContractFromApplication;
window.showDialogsList = showDialogsList;
window.openChat = openChat;
window.closeChat = closeChat;
window.deleteDialog = deleteDialog;
window.contactUser = contactUser;
window.cancelContract = cancelContract;
window.isUserLoggedIn = isUserLoggedIn;
window.initWebSocket = initWebSocket;
window.toggleNotifications = toggleNotifications;
window.toggleMessages = toggleMessages;
window.loadNotifications = loadNotifications;
window.loadRecentMessages = loadRecentMessages;
window.markAllNotificationsRead = markAllNotificationsRead;
window.updateBadges = updateBadges;
window.updateModalGallery = updateModalGallery;
window.downloadContract = downloadContract;
window.downloadAct = downloadAct;
window.exportAgentStats = exportAgentStats;
window.signContract = signContract;
window.showContractDetail = showContractDetail;
window.openFullscreenGallery = openFullscreenGallery;
window.closeFullscreenGallery = closeFullscreenGallery;
window.nextGalleryImage = nextGalleryImage;
window.prevGalleryImage = prevGalleryImage;
window.switchGuideTab = switchGuideTab;

// ========== НОВЫЕ ФУНКЦИИ ДЛЯ УПРАВЛЕНИЯ ФОТОГРАФИЯМИ ==========
window.handlePhotoSelect = handlePhotoSelect;
window.deletePhoto = deletePhoto;
window.setMainPhoto = setMainPhoto;
window.updatePhotoGrid = updatePhotoGrid;
window.displayExistingPhotos = displayExistingPhotos;

// Админ-функции
window.showAdminUsers = showAdminUsers;
window.loadAdminUsers = loadAdminUsers;
window.resetAdminUserFilters = resetAdminUserFilters;
window.showAdminUserDetail = showAdminUserDetail;
window.toggleUserBlock = toggleUserBlock;
window.showAdminProperty = showAdminProperty;
window.adminDeleteProperty = adminDeleteProperty;

console.log('script.js полностью загружен, все функции экспортированы');