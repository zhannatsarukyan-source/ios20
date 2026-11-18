// Typed i18n keys mirroring the backend catalog (`image/apps/api/src/i18n/locales/en.json`).
// Raw values are KEY IDENTIFIERS, never user-facing text. Add a key here only after it exists
// in en.json AND ru.json on the backend (see .claude/skills/i18n-keys).

enum L10nKey: String, CaseIterable, Sendable {
    // meta / app
    case metaLanguageName = "meta.language_name"
    case appName = "app.name"
    case appTagline = "app.tagline"

    // common
    case commonSave = "common.save"
    case commonCancel = "common.cancel"
    case commonDelete = "common.delete"
    case commonEdit = "common.edit"
    case commonRetry = "common.retry"
    case commonConfirm = "common.confirm"
    case commonBack = "common.back"
    case commonClose = "common.close"
    case commonDone = "common.done"
    case commonErrorGeneric = "common.error_generic"
    case commonOffline = "common.offline"
    case commonLoadingFailed = "common.loading_failed"
    case commonPullToRefresh = "common.pull_to_refresh"
    case commonIncrease = "common.increase"
    case commonDecrease = "common.decrease"

    // nav
    case navMain = "nav.main"                                // reserved (not used on iOS yet)
    case navDashboard = "nav.dashboard"
    case navHabits = "nav.habits"
    case navStats = "nav.stats"
    case navSettings = "nav.settings"

    // auth
    case authLoginTitle = "auth.login_title"
    case authLoginSubtitle = "auth.login_subtitle"
    case authRegisterTitle = "auth.register_title"
    case authRegisterSubtitle = "auth.register_subtitle"
    case authEmail = "auth.email"
    case authPassword = "auth.password"
    case authDisplayName = "auth.display_name"
    case authLoginButton = "auth.login_button"
    case authRegisterButton = "auth.register_button"
    case authNoAccount = "auth.no_account"
    case authHaveAccount = "auth.have_account"
    case authLogout = "auth.logout"
    case authLogoutConfirm = "auth.logout_confirm"
    case authShowPassword = "auth.show_password"
    case authHidePassword = "auth.hide_password"

    // dashboard
    case dashboardGreeting = "dashboard.greeting"            // {name}
    case dashboardToday = "dashboard.today"
    case dashboardProgress = "dashboard.progress"            // {done} {total}
    case dashboardEmptyTitle = "dashboard.empty_title"
    case dashboardEmptySubtitle = "dashboard.empty_subtitle"
    case dashboardAddFirst = "dashboard.add_first"
    case dashboardAllDone = "dashboard.all_done"

    // habits
    case habitsTitle = "habits.title"
    case habitsNew = "habits.new"
    case habitsEdit = "habits.edit"
    case habitsName = "habits.name"
    case habitsNamePlaceholder = "habits.name_placeholder"
    case habitsDescription = "habits.description"
    case habitsDescriptionPlaceholder = "habits.description_placeholder"
    case habitsColor = "habits.color"
    case habitsIcon = "habits.icon"
    case habitsTargetPerWeek = "habits.target_per_week"
    case habitsCheckIn = "habits.check_in"
    case habitsCheckedIn = "habits.checked_in"
    case habitsUndoCheckIn = "habits.undo_check_in"
    case habitsDeleteConfirmTitle = "habits.delete_confirm_title"
    case habitsDeleteConfirmMessage = "habits.delete_confirm_message" // {name}
    case habitsEmpty = "habits.empty"
    case habitsHistory = "habits.history"
    case habitsCreated = "habits.created"                    // {date}
    case habitsCreatedToast = "habits.created_toast"
    case habitsThisWeek = "habits.this_week"                 // {done} {target}

    // stats
    case statsTitle = "stats.title"
    case statsTotalHabits = "stats.total_habits"
    case statsCompletedToday = "stats.completed_today"
    case statsBestStreak = "stats.best_streak"
    case statsWeeklyRate = "stats.weekly_rate"
    case statsLast7Days = "stats.last_7_days"
    case statsEmpty = "stats.empty"

    // settings
    case settingsTitle = "settings.title"
    case settingsLanguage = "settings.language"
    case settingsProfile = "settings.profile"
    case settingsAbout = "settings.about"
    case settingsVersion = "settings.version"
    case settingsAccount = "settings.account"
    case settingsTheme = "settings.theme"
    case settingsThemeLight = "settings.theme_light"
    case settingsThemeDark = "settings.theme_dark"
    case settingsThemeSystem = "settings.theme_system"

    // colors (accessibility names)
    case colorCoral = "color.coral"
    case colorAmber = "color.amber"
    case colorMint = "color.mint"
    case colorSky = "color.sky"
    case colorViolet = "color.violet"
    case colorRose = "color.rose"

    // icons (accessibility names)
    case iconRun = "icon.run"
    case iconBook = "icon.book"
    case iconWater = "icon.water"
    case iconSleep = "icon.sleep"
    case iconMeditate = "icon.meditate"
    case iconCode = "icon.code"
    case iconHeart = "icon.heart"
    case iconLeaf = "icon.leaf"

    // errors
    case errorsValidation = "errors.validation"
    case errorsUnauthorized = "errors.unauthorized"
    case errorsForbidden = "errors.forbidden"
    case errorsNotFound = "errors.not_found"
    case errorsHabitNotFound = "errors.habit_not_found"
    case errorsEmailTaken = "errors.email_taken"
    case errorsInvalidCredentials = "errors.invalid_credentials"
    case errorsTokenExpired = "errors.token_expired"
    case errorsRateLimited = "errors.rate_limited"
    case errorsInternal = "errors.internal"
    case errorsNetwork = "errors.network"
    case errorsConflict = "errors.conflict"

    // validation
    case validationRequired = "validation.required"
    case validationEmailInvalid = "validation.email_invalid"
    case validationPasswordMin = "validation.password_min"   // {min}
    case validationTooLong = "validation.too_long"           // {max}
    case validationTargetRange = "validation.target_range"   // {min} {max}
}

/// Plural base keys; the catalog holds `<base>_one|_few|_many|_other`. `{count}` is injected automatically.
enum L10nPluralKey: String, CaseIterable, Sendable {
    case habitsTargetPerWeekValue = "habits.target_per_week_value"
    case habitsStreak = "habits.streak"
}
