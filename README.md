# Оперативний журнал: розгортання

Файли: `index.html` (весь сайт), `patch.sql` (виправлення прав доступу).
Збирати нічого не потрібно: сайт статичний, база та вхід працюють через Supabase.

## 1. Supabase (один раз)
1. SQL Editor: переконайтеся, що `schema.sql` виконано, потім виконайте `patch.sql`.
2. Authentication -> Sign In / Providers -> Email: за бажанням вимкніть «Confirm email».
3. Authentication -> URL Configuration: після кроку 3 нижче вставте адресу сайту з Vercel в «Site URL».

## 2. GitHub
1. Створіть порожній репозиторій (наприклад, `operativniy-zhurnal`).
2. «Add file» -> «Upload files»: завантажте `index.html` і `README.md`. Натисніть «Commit changes».

## 3. Vercel
1. vercel.com -> «Add New» -> «Project» -> оберіть репозиторій -> «Deploy».
2. Налаштування залишайте типовими (Framework Preset: Other, збірки немає).
3. Отримаєте адресу виду `ваш-журнал.vercel.app`.

## 4. Перший вхід
1. Відкрийте сайт, зареєструйтесь (пошта, пароль, прізвище, цех), намалюйте підпис.
2. У Supabase -> SQL Editor виконайте (з вашою поштою):
   update public.profiles set role = 'owner', approved = true
   where id = (select id from auth.users where email = 'ВАША_ПОШТА');
3. Оновіть сторінку: з'явиться кнопка «Управление», де ви підтверджуєте людей і призначаєте посади.

## Примітки
- Ключ у `index.html` (`sb_publishable_...`) публічний, це нормально. Ключ `secret` / `service_role` у код не вставляйте.
- Щоб людина могла писати, власник має внести її в склад зміни, вибравши її ім'я зі списку зареєстрованих.
