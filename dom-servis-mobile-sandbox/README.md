# Дом-Сервис Mobile Sandbox

Локальный стенд для быстрой итерации mobile shell мастера без Docker и без backend-зависимостей.

## Запуск

```bash
npm install
npm run dev
```

Dev server поднимается на `http://localhost:8098`.

## Что внутри

- `src/App.vue` — локальная песочница mobile shell.
- `src/data/jobs.json` — моковые заявки в форме, близкой к карточкам dispatch.
- `src/styles.css` — отдельный слой стилей с naming, близким к `dom_servis_dispatch`.

## Принцип

- sandbox не копирует backend и не тянет API;
- интерактивность работает на локальном state;
- структура блоков и class naming собраны так, чтобы потом переносить shell обратно в Дом-Сервис по частям.
