// static/hh_api.js

const HH_API = {
    // Базовый URL
    baseUrl: 'https://api.hh.ru/areas',

    // Кеш для хранения загруженных данных
    cache: null,

    // Флаг, указывающий, загружаются ли данные
    isLoading: false,

    // Очередь колбэков, которые нужно выполнить после загрузки
    callbacks: [],

    /**
     * Загружает справочник городов (один раз) и кеширует его.
     * Используется паттерн "Обещание" (Promise), чтобы избежать множественных запросов.
     * @returns {Promise<Array>} - Массив всех названий городов
     */
    loadCities: function() {
        return new Promise((resolve, reject) => {
            // Если данные уже в кеше, сразу возвращаем
            if (this.cache) {
                resolve(this.cache);
                return;
            }

            // Добавляем колбэк в очередь
            this.callbacks.push({ resolve, reject });

            // Если данные уже загружаются, не делаем новый запрос
            if (this.isLoading) {
                return;
            }

            this.isLoading = true;

            fetch(this.baseUrl)
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return response.json();
                })
                .then(data => {
                    // Извлекаем все названия населённых пунктов
                    const cityNames = this.extractCityNames(data);
                    // Сортируем для удобства (опционально)
                    cityNames.sort((a, b) => a.localeCompare(b, 'ru'));

                    this.cache = cityNames;
                    this.isLoading = false;

                    // Выполняем все ожидающие колбэки
                    this.callbacks.forEach(cb => cb.resolve(cityNames));
                    this.callbacks = [];
                })
                .catch(error => {
                    console.error('Ошибка загрузки справочника городов:', error);
                    this.isLoading = false;

                    // Отклоняем все ожидающие колбэки
                    this.callbacks.forEach(cb => cb.reject(error));
                    this.callbacks = [];

                    // В случае ошибки используем заглушку с популярными городами
                    const fallbackCities = [
                        "Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург",
                        "Казань", "Нижний Новгород", "Челябинск", "Самара", "Омск",
                        "Ростов-на-Дону", "Уфа", "Красноярск", "Воронеж", "Пермь",
                        "Волгоград", "Краснодар", "Саратов", "Тюмень"
                    ];
                    this.cache = fallbackCities;

                    this.callbacks.forEach(cb => cb.resolve(fallbackCities));
                    this.callbacks = [];
                });
        });
    },

    /**
     * Рекурсивно извлекает названия всех населённых пунктов (узлов, у которых areas пуст).
     * @param {Array} areas - Массив областей/регионов из API
     * @param {Array} result - Аккумулятор для результатов
     * @returns {Array} - Массив названий городов
     */
    extractCityNames: function(areas, result = []) {
        if (!areas || !Array.isArray(areas)) {
            return result;
        }

        for (const area of areas) {
            // Если у узла нет вложенных областей, это конечный пункт (город)
            if (!area.areas || area.areas.length === 0) {
                result.push(area.name);
            } else {
                // Если есть вложенные области, рекурсивно обходим их
                this.extractCityNames(area.areas, result);
            }
        }
        return result;
    },

    /**
     * Выполняет поиск городов по введённому запросу с вежливой паузой.
     * @param {string} query - Поисковый запрос (минимум 2 символа)
     * @param {function} callback - Функция, которая получит результаты поиска
     */
    searchCities: function(query, callback) {
        // Очищаем предыдущий таймер для вежливой паузы
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        // Если запрос пустой или меньше 2 символов, сразу вызываем колбэк с пустым массивом
        if (!query || query.trim().length < 2) {
            callback([]);
            return;
        }

        const trimmedQuery = query.trim().toLowerCase();

        // Устанавливаем новый таймер на 300 мс (вежливая пауза)
        this.searchTimeout = setTimeout(() => {
            this.loadCities()
                .then(allCities => {
                    // Фильтруем города по запросу
                    const results = allCities.filter(city =>
                        city.toLowerCase().includes(trimmedQuery)
                    );
                    // Возвращаем только первые 15 результатов, чтобы не перегружать интерфейс
                    callback(results.slice(0, 15));
                })
                .catch(error => {
                    console.error('Ошибка при поиске городов:', error);
                    callback([]);
                });
        }, 300);
    },

    /**
     * Возвращает список популярных городов
     * @param {number} limit - Максимальное количество городов
     * @param {function} callback - Функция, которая получит список городов
     */
    getPopularCities: function(limit = 10, callback) {
        const popularFallback = [
            "Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург",
            "Казань", "Нижний Новгород", "Челябинск", "Самара",
            "Омск", "Ростов-на-Дону", "Уфа", "Красноярск"
        ];

        this.loadCities()
            .then(allCities => {
                // Берём первые N городов из всего списка
                const popular = allCities.slice(0, limit);
                callback(popular);
            })
            .catch(() => {
                callback(popularFallback.slice(0, limit));
            });
    }
};

// Делаем объект доступным глобально
window.HH_API = HH_API;
console.log('✅ HH_API загружен');