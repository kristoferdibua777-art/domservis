# Стенд для скриншотов доски без поднятого Zammad

Рендерит настоящий шаблон `board.jst.eco` и контроллер `dispatch_board.coffee`
с заглушками Zammad и тестовыми заявками, затем Playwright меряет вёрстку.

```sh
H=/tmp/harness && mkdir -p $H && cp docs/overnight/tools/*.js $H && cd $H
npm init -y && npm i coffee-script@1.12.7 eco@1.1.0-rc-3 sass playwright
npx sass --no-source-map --quiet <repo>/app/assets/stylesheets/zammad.scss zammad.css
node build.js <repo> board.html
mkdir -p shots && node shoot.js $H/board.html $H/shots after board,create,detail,menu master,dispatcher > report.json
```

`report.json`: горизонтальная прокрутка, выход за край, перекрытие кнопок,
цели нажатия меньше 44×44. Chromium берётся из `/opt/pw-browsers/chromium`.
