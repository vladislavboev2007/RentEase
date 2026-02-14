// static/script.js

// Текущий режим отображения
let currentViewMode = 'grid';

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
    setTimeout(() => document.getElementById('login-email').focus(), 100);
}

function hideLoginModal() {
    document.getElementById('loginModal').style.display = 'none';
}

// ==================== УПРАВЛЕНИЕ ФИЛЬТРАМИ ====================

// Функция для поиска города
function searchCity() {
    const searchText = document.getElementById('citySearch').value;
    if (searchText.length >= 2) {
        alert(`Поиск города: ${searchText}`);
    }
}

// Сброс фильтров
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

// Сортировка объектов
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

        switch(sortBy) {
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

    // Пересобираем контейнер
    cards.forEach(card => container.appendChild(card));
}

// Переключение режима отображения
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

// ==================== ОБРАБОТЧИКИ СОБЫТИЙ ====================

// Инициализация при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    // Инициализация счетчика объектов
    const count = document.querySelectorAll('.property-card').length;
    const totalCountEl = document.getElementById('totalCount');
    if (totalCountEl) {
        totalCountEl.textContent = count;
    }

    // Автодополнение городов
    const cityInput = document.getElementById('city');
    const datalist = document.getElementById('citySuggestions');

    if (cityInput) {
        cityInput.addEventListener('input', function() {
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
        });
    }

    // Обработка выбора города из попапа
    document.querySelectorAll('.city-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const city = this.textContent;
            document.getElementById('selectedCity').textContent = city;
            const cityInput = document.getElementById('city');
            if (cityInput) {
                cityInput.value = city;
            }
            hideCityPopup();
        });
    });

    // Обработка формы входа
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
                    body: formData
                });

                const data = await response.json();

                if (data.success) {
                    alert('Вход выполнен успешно!');
                    hideLoginModal();
                    const loginLink = document.querySelector('.login');
                    if (loginLink) {
                        loginLink.innerHTML = data.user?.name || 'Личный кабинет';
                    }
                } else {
                    alert(data.message || 'Ошибка при входе');
                }
            } catch (error) {
                console.error('Ошибка:', error);
                alert('Ошибка при входе');
            }
        });
    }
});

// Закрытие по клику на фон
window.addEventListener('click', function(event) {
    if (event.target.classList.contains('popup')) {
        event.target.style.display = 'none';
    }
    if (event.target.classList.contains('modal')) {
        event.target.style.display = 'none';
    }
});

// Закрытие по ESC
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        document.querySelectorAll('.popup, .modal').forEach(el => {
            el.style.display = 'none';
        });
    }
});

// Экспорт функций для глобального доступа
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