# Инструкция по публикации проекта в GitHub

## ✅ Проверка безопасности перед публикацией

Все секретные файлы были проверены и исключены из репозитория:

### Исключенные файлы (в .gitignore):
- ✅ `**/*.tfvars` (кроме `.example` файлов)
- ✅ `**/.authorized_key.json`
- ✅ `**/credentials.env`
- ✅ `**/backend-secrets.tfvars`
- ✅ `ss` (временный файл с ключами)
- ✅ `**/*.key`
- ✅ Terraform state файлы

### Проверка:
```bash
# Проверка исключенных файлов
git check-ignore -v infrastructure/.authorized_key.json infrastructure/backend-secrets.tfvars infrastructure/terraform.tfvars

# Проверка, что секретные файлы не в индексе
git ls-files | grep -E "(\.tfvars$|\.authorized_key|credentials\.env|backend-secrets)"
# Результат: пусто (все секреты исключены)
```

## 📤 Публикация в GitHub

### Вариант 1: Создать новый репозиторий через веб-интерфейс

1. Откройте [GitHub](https://github.com)
2. Нажмите **"New repository"** (или перейдите на https://github.com/new)
3. Заполните данные:
   - **Repository name**: `diplom` (или другое имя)
   - **Description**: "Terraform infrastructure for Yandex Cloud"
   - **Visibility**: Выберите **Public** или **Private**
   - ⚠️ **НЕ** добавляйте README, .gitignore или license (они уже есть)
4. Нажмите **"Create repository"**
5. Выполните команды, которые GitHub предложит, или используйте команды ниже:

```bash
cd /home/campas/Документы/Diplom

# Добавьте remote (замените USERNAME на ваш GitHub username)
git remote add origin https://github.com/USERNAME/diplom.git

# Отправьте код в GitHub
git push -u origin main
```

### Вариант 2: Использовать GitHub CLI (gh)

Если у вас установлен GitHub CLI:

```bash
cd /home/campas/Документы/Diplom

# Создать репозиторий и отправить код
gh repo create diplom --public --source=. --remote=origin --push
```

### Вариант 3: Использовать SSH (если настроен SSH ключ)

```bash
cd /home/campas/Документы/Diplom

# Добавьте remote (замените USERNAME на ваш GitHub username)
git remote add origin git@github.com:USERNAME/diplom.git

# Отправьте код в GitHub
git push -u origin main
```

## 🔐 Настройка GitHub Secrets после публикации

После публикации репозитория на GitHub необходимо добавить секреты для GitHub Actions:

1. Откройте ваш репозиторий на GitHub
2. Перейдите в **Settings** → **Secrets and variables** → **Actions**
3. Добавьте следующие секреты:
   - `YC_SERVICE_ACCOUNT_KEY` - JSON ключ сервисного аккаунта
   - `AWS_ACCESS_KEY_ID` - Access Key ID для S3 backend
   - `AWS_SECRET_ACCESS_KEY` - Secret Access Key для S3 backend

Подробные инструкции см. в файле [`gh_act_var_help.md`](gh_act_var_help.md).

## 📋 Чеклист перед публикацией

- [x] ✅ Все секретные файлы исключены из репозитория
- [x] ✅ `.gitignore` настроен правильно
- [x] ✅ Git репозиторий инициализирован
- [x] ✅ Первый коммит создан
- [ ] ⬜ Репозиторий создан на GitHub
- [ ] ⬜ Код отправлен в GitHub
- [ ] ⬜ GitHub Secrets настроены
- [ ] ⬜ GitHub Actions workflow протестирован

## ⚠️ Важные напоминания

1. **Никогда не коммитьте секреты** - они останутся в истории git даже после удаления
2. **Проверьте `.gitignore`** перед каждым коммитом
3. **Используйте GitHub Secrets** для хранения чувствительных данных
4. **Регулярно ротируйте ключи** для безопасности

## 🔍 Проверка после публикации

После публикации репозитория проверьте:

```bash
# Клонируйте репозиторий в другое место и проверьте
cd /tmp
git clone https://github.com/YOUR_USERNAME/diplom.git test-check
cd test-check

# Убедитесь, что секретные файлы отсутствуют
ls -la infrastructure/*.tfvars 2>&1 || echo "✅ Файлы с секретами отсутствуют"
ls -la infrastructure/.authorized_key.json 2>&1 || echo "✅ Ключи отсутствуют"
ls -la infrastructure/backend-secrets.tfvars 2>&1 || echo "✅ Backend секреты отсутствуют"

# Удалите тестовый клон
cd ..
rm -rf test-check
```

## 📚 Дополнительные ресурсы

- [GitHub - Creating a new repository](https://docs.github.com/en/get-started/quickstart/create-a-repo)
- [GitHub - Managing remote repositories](https://docs.github.com/en/get-started/getting-started-with-git/managing-remote-repositories)
- [GitHub Actions - Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

