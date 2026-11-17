/*
 * =============================================================================
 *  SAN ANDREAS RP — Банки, мультивалютность и отмывание денег
 *  Файл:      gamemodes/modules/systems/mod_banking.pwn
 *  Пункт:     ROADMAP [7.1] — Банки, мультивалютность и отмывание денег
 *  Кодировка: Windows-1251 (CP1251) без BOM
 * =============================================================================
 */

#if defined _mod_banking_included
    #endinput
#endif
#define _mod_banking_included

#include <YSI_Coding\y_hooks>

// =============================================================================
//  1. КОНСТАНТЫ БАНКОВСКОЙ СИСТЕМЫ, КУРСОВ И ДИАЛОГОВ
// =============================================================================

#define DIALOG_BANK_MAIN                        (1400)
#define DIALOG_BANK_AMOUNT                      (1401)
#define DIALOG_BANK_TRANSFER_IBAN               (1402)
#define DIALOG_BANK_TRANSFER_AMOUNT             (1403)
#define DIALOG_BANK_LAUNDER_AMOUNT              (1404)
#define DIALOG_BANK_EXCHANGE_MENU               (1405)
#define DIALOG_BANK_EXCHANGE_AMOUNT             (1406)
#define DIALOG_BANK_STATEMENT                   (1407)
#define DIALOG_BANK_LAUNDER_LIST                (1408)

#define BANK_BRANCH_COUNT                       (3)
#define BANK_BRANCH_INTERACT_DISTANCE           (5.0)
#define BANK_LAUNDER_INTERACT_DISTANCE          (15.0)
#define BANK_STATEMENT_MAX_ROWS                 (8)
#define BANK_STATEMENT_BUFFER_LEN               (3072)
#define BANK_MAX_MENU_ACTIONS                   (10)
#define BANK_MAX_LAUNDER_ROWS                   (32)
#define BANK_LAUNDER_BASE_TAX_PERCENT           (15)
#define BANK_LAUNDER_MAX_TAX_PERCENT            (25)
#define BANK_LAUNDER_TAX_STEP_USD               (25000)
#define BANK_STATE_AVG_DAILY_TURNOVER_USD       (50000)
#define BANK_LAUNDER_ALERT_MULTIPLIER           (3)
#define BANK_COMMAND_COOLDOWN_MS                (500)

// Курсы обмена физической валюты (в центах США за 1 единицу валюты).
// Банк продает валюту дороже, а покупает дешевле: спред защищает экономику.
#define BANK_EUR_SELL_RATE_CENTS                (108)
#define BANK_EUR_BUY_RATE_CENTS                 (104)
#define BANK_CNY_SELL_RATE_CENTS                (15)
#define BANK_CNY_BUY_RATE_CENTS                 (13)

// Асинхронные уведомления аналитикам ФБР/Минфина (реализуются mod_organizations)
forward Organizations_SendFinancialAlert(source_org_id, actor_char_id, amount, const details[]);
forward Organizations_AddGovernmentFunds(amount, const details[]);
forward bool:Banking_DebitAccount(playerid, amount, const reason[]);
forward bool:Banking_CreditAccount(playerid, amount, const reason[]);

// =============================================================================
//  2. ПЕРЕЧИСЛЕНИЯ И ИНКАПСУЛИРОВАННЫЕ МАССИВЫ СОСТОЯНИЯ (static stock)
// =============================================================================

enum E_BANK_ACTION
{
    BANK_ACTION_NONE = 0,
    BANK_ACTION_OPEN_ACCOUNT,
    BANK_ACTION_DEPOSIT,
    BANK_ACTION_WITHDRAW,
    BANK_ACTION_TRANSFER_IBAN,
    BANK_ACTION_TRANSFER_AMOUNT,
    BANK_ACTION_LAUNDER,
    BANK_ACTION_EXCHANGE,
    BANK_ACTION_STATEMENT,
    BANK_ACTION_CASH_INFO
};

static stock E_BANK_ACTION:sBankAction[MAX_PLAYERS];
static stock sBankAmount[MAX_PLAYERS];
static stock sBankExchangeFrom[MAX_PLAYERS];
static stock sBankExchangeTo[MAX_PLAYERS];
static stock sBankTargetIban[MAX_PLAYERS][24];
static stock sBankMenuAction[MAX_PLAYERS][BANK_MAX_MENU_ACTIONS];
static stock sBankMenuActionCount[MAX_PLAYERS];
static stock sBankLaunderRowMap[MAX_PLAYERS][BANK_MAX_LAUNDER_ROWS];
static stock sBankLaunderRowCount[MAX_PLAYERS];
static stock sBankLaunderEnterprise[MAX_PLAYERS];
static stock sBankLastCommandTick[MAX_PLAYERS];
static stock sBankDailyLaunderVolume[MAX_ENTERPRISES];
static stock sBankDailyLaunderDay[MAX_ENTERPRISES];
static stock bool:sBankLaunderAlertSent[MAX_ENTERPRISES];

static stock const Float:sBankBranches[BANK_BRANCH_COUNT][3] =
{
    { 1461.5, -1012.5, 26.8 },      // Центральный банк Лос-Сантоса
    { -1981.5, 137.3, 27.7 },       // Банк Сан-Фиерро
    { 2134.2, 1990.1, 10.8 }        // Банк Лас-Вентураса
};

// =============================================================================
//  3. ВНУТРЕННИЕ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (static stock)
// =============================================================================

static stock Internal_GetCurrencyCode(currency, output[], len = sizeof(output))
{
    switch (currency)
    {
        case CURRENCY_USD: format(output, len, "USD");
        case CURRENCY_EUR: format(output, len, "EUR");
        case CURRENCY_CNY: format(output, len, "CNY");
        default:           format(output, len, "USD");
    }
    return 1;
}

static stock Internal_GetCurrencyNameRu(currency, output[], len = sizeof(output))
{
    switch (currency)
    {
        case CURRENCY_USD: format(output, len, "Доллары США (USD)");
        case CURRENCY_EUR: format(output, len, "Евро (EUR)");
        case CURRENCY_CNY: format(output, len, "Китайские юани (CNY)");
        default:           format(output, len, "Неизвестная валюта");
    }
    return 1;
}

static stock Internal_GetCashFlagNameRu(cash_flag, output[], len = sizeof(output))
{
    if (cash_flag == CASH_FLAG_DIRTY)
    {
        format(output, len, "грязные");
    }
    else
    {
        format(output, len, "чистые");
    }
    return 1;
}

static stock Internal_FormatCurrencyAmount(amount, currency, output[], len = sizeof(output))
{
    if (currency == CURRENCY_USD)
    {
        Utils_FormatMoney(amount, output, len);
    }
    else
    {
        new code[8];
        Internal_GetCurrencyCode(currency, code, sizeof(code));
        format(output, len, "%d %s", amount, code);
    }
    return 1;
}

static stock bool:Internal_IsPlayerNearBankBranch(playerid)
{
    if (!IsPlayerConnected(playerid))
    {
        return false;
    }
    for (new i = 0; i < BANK_BRANCH_COUNT; i++)
    {
        if (Utils_IsPlayerNearPoint(
            playerid,
            BANK_BRANCH_INTERACT_DISTANCE,
            sBankBranches[i][0],
            sBankBranches[i][1],
            sBankBranches[i][2]))
        {
            return true;
        }
    }
    return false;
}

static stock Internal_FindPlayerByCharId(char_db_id)
{
    if (char_db_id <= 0)
    {
        return INVALID_PLAYER_ID;
    }
    foreach (new playerid : Player)
    {
        if (Character_IsLoaded(playerid) && Character_GetId(playerid) == char_db_id)
        {
            return playerid;
        }
    }
    return INVALID_PLAYER_ID;
}

static stock Internal_CountCash(playerid, currency, cash_flag)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid))
    {
        return 0;
    }

    new total = 0;
    new slots[2];
    slots[0] = Character_GetLayer1Slot(playerid);
    slots[1] = Character_GetLayer2Slot(playerid);

    for (new s = 0; s < 2; s++)
    {
        if (!Storage_IsValidSlot(slots[s]))
        {
            continue;
        }
        new itemSlot = Storage_GetFirstItemSlot(slots[s]);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
        {
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_CASH_BUNDLE &&
                Storage_GetItemMetaInt2(itemSlot) == currency &&
                (cash_flag < 0 || Storage_GetItemMetaInt1(itemSlot) == cash_flag))
            {
                total += Storage_GetItemAmount(itemSlot);
            }
            itemSlot = Storage_GetNextItemSlot(itemSlot);
        }
    }
    return total;
}

static stock bool:Internal_RemoveCash(playerid, currency, cash_flag, amount)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid) || amount <= 0)
    {
        return false;
    }
    if (Internal_CountCash(playerid, currency, cash_flag) < amount)
    {
        return false;
    }

    new remaining = amount;
    new slots[2];
    slots[0] = Character_GetLayer1Slot(playerid);
    slots[1] = Character_GetLayer2Slot(playerid);

    for (new s = 0; s < 2 && remaining > 0; s++)
    {
        if (!Storage_IsValidSlot(slots[s]))
        {
            continue;
        }
        new itemSlot = Storage_GetFirstItemSlot(slots[s]);
        while (itemSlot != INVALID_STORAGE_ITEM_SLOT && remaining > 0)
        {
            new const nextItemSlot = Storage_GetNextItemSlot(itemSlot);
            if (Storage_GetItemDefId(itemSlot) == ITEM_ID_CASH_BUNDLE &&
                Storage_GetItemMetaInt2(itemSlot) == currency &&
                (cash_flag < 0 || Storage_GetItemMetaInt1(itemSlot) == cash_flag))
            {
                new const stackAmount = Storage_GetItemAmount(itemSlot);
                new const takeAmount = (stackAmount > remaining) ? remaining : stackAmount;
                if (Storage_RemoveItem(slots[s], itemSlot, takeAmount))
                {
                    remaining -= takeAmount;
                }
            }
            itemSlot = nextItemSlot;
        }
    }
    return (remaining == 0);
}

static stock bool:Internal_AddCash(playerid, currency, cash_flag, amount)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS || !Character_IsLoaded(playerid) || amount <= 0)
    {
        return false;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (!Storage_IsValidSlot(layer1Slot))
    {
        return false;
    }

    new const cashWeightG = Item_CalculateInstanceWeight(ITEM_ID_CASH_BUNDLE, amount);
    new const cashVolumeMl = Item_CalculateInstanceVolume(ITEM_ID_CASH_BUNDLE, amount);
    if ((Storage_GetCurrentWeight(layer1Slot) + cashWeightG) > Storage_GetMaxWeight(layer1Slot) ||
        (Storage_GetCurrentVolume(layer1Slot) + cashVolumeMl) > Storage_GetMaxVolume(layer1Slot))
    {
        return false;
    }

    new currencyCode[8], currencyName[32];
    Internal_GetCurrencyCode(currency, currencyCode, sizeof(currencyCode));
    Internal_GetCurrencyNameRu(currency, currencyName, sizeof(currencyName));

    new remaining = amount;
    new added = 0;
    while (remaining > 0)
    {
        new const chunk = (remaining > 10000) ? 10000 : remaining;
        new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
        new const E_STORAGE_RESULT:result = Storage_AddItem(
            layer1Slot,
            ITEM_ID_CASH_BUNDLE,
            chunk,
            0,
            100.0,
            cash_flag,
            currency,
            currencyCode,
            outItemSlot);

        if (result != STORAGE_RES_OK)
        {
            if (added > 0)
            {
                Internal_RemoveCash(playerid, currency, cash_flag, added);
            }
            return false;
        }

        added += chunk;
        remaining -= chunk;
    }
    return true;
}

static stock bool:Internal_PlayerHasItemDef(playerid, storage_slot, def_id)
{
    #pragma unused playerid
    if (!Storage_IsValidSlot(storage_slot))
    {
        return false;
    }
    new itemSlot = Storage_GetFirstItemSlot(storage_slot);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == def_id)
        {
            return true;
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return false;
}

static stock bool:Internal_HasPassportWithSsn(playerid, const ssn[])
{
    if (ssn[0] == EOS)
    {
        return false;
    }
    new const layer2 = Character_GetLayer2Slot(playerid);
    if (!Storage_IsValidSlot(layer2))
    {
        return false;
    }
    new itemSlot = Storage_GetFirstItemSlot(layer2);
    while (itemSlot != INVALID_STORAGE_ITEM_SLOT)
    {
        if (Storage_GetItemDefId(itemSlot) == ITEM_ID_PASSPORT)
        {
            new passportSsn[32];
            Storage_GetItemMetaStr(itemSlot, passportSsn, sizeof(passportSsn));
            if (!strcmp(passportSsn, ssn, false))
            {
                return true;
            }
        }
        itemSlot = Storage_GetNextItemSlot(itemSlot);
    }
    return false;
}

static stock Internal_IssueBankCard(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }
    new const layer2Slot = Character_GetLayer2Slot(playerid);
    if (!Storage_IsValidSlot(layer2Slot))
    {
        return 0;
    }
    if (Internal_PlayerHasItemDef(playerid, layer2Slot, ITEM_ID_BANK_CARD))
    {
        return 1;
    }

    new cardMeta[32];
    format(cardMeta, sizeof(cardMeta), "BANK-CARD-%d", Character_GetId(playerid));
    new outItemSlot = INVALID_STORAGE_ITEM_SLOT;
    return (Storage_AddItem(
        layer2Slot,
        ITEM_ID_BANK_CARD,
        1,
        0,
        100.0,
        Character_GetBankAccountDbId(playerid),
        CURRENCY_USD,
        cardMeta,
        outItemSlot) == STORAGE_RES_OK);
}

static stock Internal_ShowMainMenu(playerid)
{
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new const bool:hasAccount = Character_HasBankAccount(playerid);
    new balanceStr[32];
    Utils_FormatMoney(Character_GetBankBalanceUsd(playerid), balanceStr);

    new caption[144];
    if (hasAccount)
    {
        format(caption, sizeof(caption),
            "{FFC800}Центральный банк Сан-Андреаса {FFFFFF}| Баланс: {66CC66}%s",
            balanceStr);
    }
    else
    {
        format(caption, sizeof(caption),
            "{FFC800}Центральный банк Сан-Андреаса {FFFFFF}| Счет не открыт");
    }

    new body[1024];
    new actionCount = 0;
    body[0] = '\0';

    if (hasAccount)
    {
        strcat(body, "Пополнить счет наличными\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_DEPOSIT;
        strcat(body, "Снять наличные со счета\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_WITHDRAW;
        strcat(body, "Перевод другому клиенту по IBAN\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_TRANSFER_IBAN;
        strcat(body, "Обмен физической валюты\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_EXCHANGE;
        strcat(body, "Выписка по счету\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_STATEMENT;
        strcat(body, "Легализовать грязные наличные через бизнес\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_LAUNDER;
        strcat(body, "Проверить наличные и валютные пачки\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_CASH_INFO;
    }
    else
    {
        strcat(body, "Открыть банковский счет\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_OPEN_ACCOUNT;
        strcat(body, "Проверить наличные и валютные пачки\n", sizeof(body));
        sBankMenuAction[playerid][actionCount++] = _:BANK_ACTION_CASH_INFO;
    }

    sBankMenuActionCount[playerid] = actionCount;
    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_MAIN,
        DIALOG_STYLE_LIST,
        caption,
        body,
        "Выбрать",
        "Закрыть");
    return 1;
}

static stock Internal_ShowExchangeMenu(playerid)
{
    sBankMenuActionCount[playerid] = 4;
    sBankMenuAction[playerid][0] = CURRENCY_USD;
    sBankMenuAction[playerid][1] = CURRENCY_EUR;
    sBankMenuAction[playerid][2] = CURRENCY_USD;
    sBankMenuAction[playerid][3] = CURRENCY_CNY;

    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_EXCHANGE_MENU,
        DIALOG_STYLE_LIST,
        "{FFC800}Обменный пункт Центрального банка",
        "Купить евро за доллары США (курс 1 EUR = 1.08 USD)\n" \
        "Продать евро за доллары США (курс 1 EUR = 1.04 USD)\n" \
        "Купить китайские юани за доллары США (курс 1 CNY = 0.15 USD)\n" \
        "Продать китайские юани за доллары США (курс 1 CNY = 0.13 USD)",
        "Выбрать",
        "Закрыть");
    return 1;
}

static stock Internal_ShowCashInfo(playerid)
{
    new usdClean, eurClean, cnyClean, usdDirty;
    usdClean = Internal_CountCash(playerid, CURRENCY_USD, CASH_FLAG_CLEAN);
    eurClean = Internal_CountCash(playerid, CURRENCY_EUR, CASH_FLAG_CLEAN);
    cnyClean = Internal_CountCash(playerid, CURRENCY_CNY, CASH_FLAG_CLEAN);
    usdDirty = Internal_CountCash(playerid, CURRENCY_USD, CASH_FLAG_DIRTY);

    new usdStr[32], eurStr[32], cnyStr[32], dirtyStr[32];
    Utils_FormatMoney(usdClean, usdStr);
    Internal_FormatCurrencyAmount(eurClean, CURRENCY_EUR, eurStr);
    Internal_FormatCurrencyAmount(cnyClean, CURRENCY_CNY, cnyStr);
    Utils_FormatMoney(usdDirty, dirtyStr);

    new body[512];
    format(body, sizeof(body),
        "{FFC800}Наличные в вашем инвентаре:{FFFFFF}\n" \
        "• Доллары США (USD), чистые: {66CC66}%s{FFFFFF}\n" \
        "• Евро (EUR), чистые: {66CC66}%s{FFFFFF}\n" \
        "• Китайские юани (CNY), чистые: {66CC66}%s{FFFFFF}\n" \
        "• Доллары США (USD), грязные: {FFAA00}%s{FFFFFF}\n\n" \
        "Грязные наличные не принимаются банкоматами. Их можно легализовать через кассу собственного легального бизнеса.",
        usdStr, eurStr, cnyStr, dirtyStr);

    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_STATEMENT,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}Наличные и валютные пачки",
        body,
        "Понятно",
        "Закрыть");
    return 1;
}

static stock Internal_ShowDepositInput(playerid)
{
    sBankAction[playerid] = BANK_ACTION_DEPOSIT;
    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_AMOUNT,
        DIALOG_STYLE_INPUT,
        "{FFC800}Пополнение банковского счета",
        "Введите сумму чистых наличных USD для внесения на счет.\n" \
        "Грязные наличные банкоматом не принимаются.",
        "Внести",
        "Отмена");
    return 1;
}

static stock Internal_ShowWithdrawInput(playerid)
{
    new balanceStr[32];
    Utils_FormatMoney(Character_GetBankBalanceUsd(playerid), balanceStr);
    sBankAction[playerid] = BANK_ACTION_WITHDRAW;

    new body[256];
    format(body, sizeof(body),
        "Введите сумму USD для снятия наличными.\n" \
        "Доступный остаток на счете: %s.",
        balanceStr);
    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_AMOUNT,
        DIALOG_STYLE_INPUT,
        "{FFC800}Снятие наличных со счета",
        body,
        "Снять",
        "Отмена");
    return 1;
}

static stock Internal_ShowTransferIbanInput(playerid)
{
    sBankAction[playerid] = BANK_ACTION_TRANSFER_IBAN;
    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_TRANSFER_IBAN,
        DIALOG_STYLE_INPUT,
        "{FFC800}Перевод по IBAN",
        "Введите IBAN получателя в формате SA00XXXX00000000.\n" \
        "Перевод выполняется только в долларах США (USD).",
        "Продолжить",
        "Отмена");
    return 1;
}

static stock Internal_ShowTransferAmountInput(playerid)
{
    new balanceStr[32];
    Utils_FormatMoney(Character_GetBankBalanceUsd(playerid), balanceStr);
    sBankAction[playerid] = BANK_ACTION_TRANSFER_AMOUNT;

    new body[320];
    format(body, sizeof(body),
        "Получатель: %s\n" \
        "Доступный остаток: %s\n\n" \
        "Введите сумму перевода в USD.",
        sBankTargetIban[playerid],
        balanceStr);
    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_TRANSFER_AMOUNT,
        DIALOG_STYLE_INPUT,
        "{FFC800}Сумма банковского перевода",
        body,
        "Перевести",
        "Отмена");
    return 1;
}

static stock Internal_ShowStatement(playerid)
{
    if (!DB_IsConnected())
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Выписка временно недоступна: нет соединения с банковской базой данных.");
        return 0;
    }

    new const charId = Character_GetId(playerid);
    if (charId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Не удалось определить идентификатор вашего персонажа.");
        return 0;
    }

    new query[384];
    mysql_format(gMySQL, query, sizeof(query),
        "SELECT `action_type`, `amount`, IFNULL(`details`, '') AS `details`, `created_at` FROM `audit_logs` WHERE `actor_char_id` = %d AND (`action_type` LIKE 'BANK%%' OR `action_type` = 'MONEY_LAUNDER') ORDER BY `id` DESC LIMIT %d;",
        charId,
        BANK_STATEMENT_MAX_ROWS);
    mysql_tquery(gMySQL, query, "OnBankStatementLoaded", "dd",
        playerid,
        Config_GetPlayerSessionToken(playerid));
    return 1;
}

static stock Internal_ExecuteDeposit(playerid, amount)
{
    if (!Character_HasBankAccount(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "У вас нет открытого банковского счета.");
        return 0;
    }
    if (Character_IsBankFrozen(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Ваш банковский счет заморожен по решению суда или ФБР.");
        return 0;
    }
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Сумма пополнения должна быть положительной.");
        return 0;
    }
    if (Internal_CountCash(playerid, CURRENCY_USD, CASH_FLAG_CLEAN) < amount)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "У вас недостаточно чистых наличных долларов США для пополнения счета.");
        return 0;
    }
    if (!Internal_RemoveCash(playerid, CURRENCY_USD, CASH_FLAG_CLEAN, amount))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось изъять наличные из инвентаря.");
        return 0;
    }
    if (!Banking_CreditAccount(playerid, amount, "Пополнение счета наличными"))
    {
        Internal_AddCash(playerid, CURRENCY_USD, CASH_FLAG_CLEAN, amount);
        SendClientMessage(playerid, COLOR_UI_ERROR, "Банк отклонил операцию пополнения счета.");
        return 0;
    }

    new amountStr[32], balanceStr[32];
    Utils_FormatMoney(amount, amountStr);
    Utils_FormatMoney(Character_GetBankBalanceUsd(playerid), balanceStr);

    new msg[192];
    format(msg, sizeof(msg),
        "Вы внесли %s на банковский счет. Текущий баланс: %s.",
        amountStr, balanceStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    return 1;
}

static stock Internal_ExecuteWithdraw(playerid, amount)
{
    if (!Character_HasBankAccount(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "У вас нет открытого банковского счета.");
        return 0;
    }
    if (Character_IsBankFrozen(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Ваш банковский счет заморожен. Снятие наличных невозможно.");
        return 0;
    }
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Сумма снятия должна быть положительной.");
        return 0;
    }
    if (Character_GetBankBalanceUsd(playerid) < amount)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "На счете недостаточно средств для снятия указанной суммы.");
        return 0;
    }

    new const layer1Slot = Character_GetLayer1Slot(playerid);
    if (Storage_IsValidSlot(layer1Slot))
    {
        new const cashWeightG = Item_CalculateInstanceWeight(ITEM_ID_CASH_BUNDLE, amount);
        new const cashVolumeMl = Item_CalculateInstanceVolume(ITEM_ID_CASH_BUNDLE, amount);
        if ((Storage_GetCurrentWeight(layer1Slot) + cashWeightG) > Storage_GetMaxWeight(layer1Slot) ||
            (Storage_GetCurrentVolume(layer1Slot) + cashVolumeMl) > Storage_GetMaxVolume(layer1Slot))
        {
            SendClientMessage(playerid, COLOR_UI_ERROR,
                "В инвентаре недостаточно места для такой суммы наличных.");
            return 0;
        }
    }

    if (!Banking_DebitAccount(playerid, amount, "Снятие наличных со счета"))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Банк отклонил операцию снятия.");
        return 0;
    }
    if (!Internal_AddCash(playerid, CURRENCY_USD, CASH_FLAG_CLEAN, amount))
    {
        Banking_CreditAccount(playerid, amount, "Возврат после неудачного снятия");
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Не удалось выдать наличные: инвентарь переполнен. Операция отменена.");
        return 0;
    }

    new amountStr[32], balanceStr[32];
    Utils_FormatMoney(amount, amountStr);
    Utils_FormatMoney(Character_GetBankBalanceUsd(playerid), balanceStr);

    new msg[192];
    format(msg, sizeof(msg),
        "Вы сняли %s наличными. Текущий баланс: %s.",
        amountStr, balanceStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);
    return 1;
}

static stock Internal_ExecuteExchange(playerid, fromCurrency, toCurrency, amount)
{
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Сумма обмена должна быть положительной.");
        return 0;
    }
    if (fromCurrency == toCurrency)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Выберите разные валюты для обмена.");
        return 0;
    }
    if (Internal_CountCash(playerid, fromCurrency, CASH_FLAG_CLEAN) < amount)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "У вас недостаточно чистых наличных выбранной валюты.");
        return 0;
    }

    new targetAmount = 0;
    if (fromCurrency == CURRENCY_USD && toCurrency == CURRENCY_EUR)
    {
        targetAmount = (amount * 100) / BANK_EUR_SELL_RATE_CENTS;
    }
    else if (fromCurrency == CURRENCY_EUR && toCurrency == CURRENCY_USD)
    {
        targetAmount = (amount * BANK_EUR_BUY_RATE_CENTS) / 100;
    }
    else if (fromCurrency == CURRENCY_USD && toCurrency == CURRENCY_CNY)
    {
        targetAmount = (amount * 100) / BANK_CNY_SELL_RATE_CENTS;
    }
    else if (fromCurrency == CURRENCY_CNY && toCurrency == CURRENCY_USD)
    {
        targetAmount = (amount * BANK_CNY_BUY_RATE_CENTS) / 100;
    }
    else
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Такой обменный курс не поддерживается.");
        return 0;
    }

    if (targetAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Сумма слишком мала для обмена.");
        return 0;
    }

    if (!Internal_RemoveCash(playerid, fromCurrency, CASH_FLAG_CLEAN, amount))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось изъять исходную валюту.");
        return 0;
    }
    if (!Internal_AddCash(playerid, toCurrency, CASH_FLAG_CLEAN, targetAmount))
    {
        Internal_AddCash(playerid, fromCurrency, CASH_FLAG_CLEAN, amount);
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не хватает места для целевой валюты. Обмен отменен.");
        return 0;
    }

    new fromName[32], toName[32], fromStr[32], toStr[32];
    Internal_GetCurrencyNameRu(fromCurrency, fromName, sizeof(fromName));
    Internal_GetCurrencyNameRu(toCurrency, toName, sizeof(toName));
    Internal_FormatCurrencyAmount(amount, fromCurrency, fromStr);
    Internal_FormatCurrencyAmount(targetAmount, toCurrency, toStr);

    new msg[256];
    format(msg, sizeof(msg),
        "Обмен выполнен: %s %s -> %s %s.",
        fromStr, fromName, toStr, toName);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new details[160];
    format(details, sizeof(details), "Обмен %s на %s в отделении банка", fromName, toName);
    Audit_Log(Character_GetId(playerid), "BANK_EXCHANGE", "PHYSICAL_CASH", "PHYSICAL_CASH",
        ITEM_ID_CASH_BUNDLE, amount, details);
    return 1;
}

static stock bool:Internal_IsLaunderEnterpriseType(E_ENTERPRISE_TYPE:type)
{
    switch (type)
    {
        case ENTERPRISE_RETAIL_SHOP,
             ENTERPRISE_GAS_STATION,
             ENTERPRISE_REFINERY,
             ENTERPRISE_FACTORY:
        {
            return true;
        }
    }
    return false;
}

static stock Internal_ShowLaunderMenu(playerid)
{
    if (!Character_HasBankAccount(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Для легализации грязных наличных необходим открытый банковский счет.");
        return 0;
    }
    if (Character_IsBankFrozen(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Ваш банковский счет заморожен: легализация невозможна.");
        return 0;
    }
    if (Internal_CountCash(playerid, CURRENCY_USD, CASH_FLAG_DIRTY) <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "У вас нет грязных наличных долларов США.");
        return 0;
    }

    new charId = Character_GetId(playerid);
    new rowCount = 0;
    new dialogBody[1024];
    dialogBody[0] = '\0';

    foreach (new enterpriseId : EnterpriseIter)
    {
        if (!Enterprise_IsValid(enterpriseId) || rowCount >= BANK_MAX_LAUNDER_ROWS)
        {
            continue;
        }
        if (Enterprise_GetOwnership(enterpriseId) != ENTERPRISE_OWN_PRIVATE)
        {
            continue;
        }
        if (Enterprise_GetOwnerCharId(enterpriseId) != charId)
        {
            continue;
        }
        if (!Internal_IsLaunderEnterpriseType(Enterprise_GetType(enterpriseId)))
        {
            continue;
        }

        new Float:ex, Float:ey, Float:ez;
        if (!Enterprise_GetPos(enterpriseId, ex, ey, ez))
        {
            continue;
        }
        if (!Utils_IsPlayerNearPoint(playerid, BANK_LAUNDER_INTERACT_DISTANCE, ex, ey, ez))
        {
            continue;
        }

        new entName[64], typeName[48], row[160];
        Enterprise_GetName(enterpriseId, entName, sizeof(entName));
        Enterprise_GetTypeTitleRu(Enterprise_GetType(enterpriseId), typeName, sizeof(typeName));
        format(row, sizeof(row), "%s | %s\n", entName, typeName);
        if ((strlen(dialogBody) + strlen(row)) >= sizeof(dialogBody))
        {
            break;
        }
        strcat(dialogBody, row, sizeof(dialogBody));
        sBankLaunderRowMap[playerid][rowCount++] = enterpriseId;
    }

    sBankLaunderRowCount[playerid] = rowCount;
    if (rowCount == 0)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Рядом нет вашего легального бизнеса с кассой для легализации наличных.");
        return 0;
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_LAUNDER_LIST,
        DIALOG_STYLE_LIST,
        "{FFC800}Легализация грязных наличных через кассу бизнеса",
        dialogBody,
        "Выбрать",
        "Отмена");
    return 1;
}

static stock Internal_ExecuteLaunder(playerid, enterpriseId, amount)
{
    if (!Enterprise_IsValid(enterpriseId))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Предприятие не найдено.");
        return 0;
    }
    if (Enterprise_GetOwnership(enterpriseId) != ENTERPRISE_OWN_PRIVATE ||
        Enterprise_GetOwnerCharId(enterpriseId) != Character_GetId(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы не являетесь владельцем этого предприятия.");
        return 0;
    }
    if (!Internal_IsLaunderEnterpriseType(Enterprise_GetType(enterpriseId)))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Это предприятие не имеет права принимать наличные.");
        return 0;
    }

    new Float:ex, Float:ey, Float:ez;
    if (!Enterprise_GetPos(enterpriseId, ex, ey, ez) ||
        !Utils_IsPlayerNearPoint(playerid, BANK_LAUNDER_INTERACT_DISTANCE, ex, ey, ez))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Вы слишком далеко от кассы предприятия.");
        return 0;
    }

    if (!Character_HasBankAccount(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "У вас нет банковского счета для зачисления чистых средств.");
        return 0;
    }
    if (Character_IsBankFrozen(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Ваш банковский счет заморожен.");
        return 0;
    }
    if (amount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Сумма легализации должна быть положительной.");
        return 0;
    }
    if (Internal_CountCash(playerid, CURRENCY_USD, CASH_FLAG_DIRTY) < amount)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "У вас недостаточно грязных наличных долларов США.");
        return 0;
    }

    new taxPercent = BANK_LAUNDER_BASE_TAX_PERCENT + (amount / BANK_LAUNDER_TAX_STEP_USD);
    if (taxPercent > BANK_LAUNDER_MAX_TAX_PERCENT)
    {
        taxPercent = BANK_LAUNDER_MAX_TAX_PERCENT;
    }
    if (Roles_HasPerk(Character_GetRoleId(playerid), PERK_TAX_DISCOUNT_20))
    {
        taxPercent = (taxPercent * 80) / 100;
    }

    new const taxAmount = (amount * taxPercent) / 100;
    new const netAmount = amount - taxAmount;
    if (netAmount <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "После уплаты налога сумма к зачислению равна нулю.");
        return 0;
    }

    if (!Internal_RemoveCash(playerid, CURRENCY_USD, CASH_FLAG_DIRTY, amount))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Не удалось изъять грязные наличные из инвентаря.");
        return 0;
    }
    if (!Banking_CreditAccount(playerid, netAmount, "Легализация наличных через кассу предприятия"))
    {
        Internal_AddCash(playerid, CURRENCY_USD, CASH_FLAG_DIRTY, amount);
        SendClientMessage(playerid, COLOR_UI_ERROR, "Банк отклонил зачисление чистых средств.");
        return 0;
    }

    new const today = gettime() / 86400;
    if (sBankDailyLaunderDay[enterpriseId] != today)
    {
        sBankDailyLaunderDay[enterpriseId] = today;
        sBankDailyLaunderVolume[enterpriseId] = 0;
        sBankLaunderAlertSent[enterpriseId] = false;
    }
    sBankDailyLaunderVolume[enterpriseId] += amount;

    new amountStr[32], netStr[32], taxStr[32];
    Utils_FormatMoney(amount, amountStr);
    Utils_FormatMoney(netAmount, netStr);
    Utils_FormatMoney(taxAmount, taxStr);

    new msg[288];
    format(msg, sizeof(msg),
        "Легализация завершена: %s грязных наличных. Удержан налог %d%% (%s), на счет зачислено %s.",
        amountStr, taxPercent, taxStr, netStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new details[192];
    format(details, sizeof(details),
        "Легализация через предприятие #%d, налог %d%%, зачислено %d USD",
        Enterprise_GetDbId(enterpriseId), taxPercent, netAmount);
    Audit_Log(Character_GetId(playerid), "MONEY_LAUNDER", "DIRTY_CASH", "BANK_ACCOUNT",
        ITEM_ID_CASH_BUNDLE, amount, details);

    if (taxAmount > 0)
    {
        new taxDetails[160];
        format(taxDetails, sizeof(taxDetails),
            "Налог на легализацию от персонажа #%d через предприятие #%d",
            Character_GetId(playerid), Enterprise_GetDbId(enterpriseId));
        Organizations_AddGovernmentFunds(taxAmount, taxDetails);
    }

    if (sBankDailyLaunderVolume[enterpriseId] > (BANK_STATE_AVG_DAILY_TURNOVER_USD * BANK_LAUNDER_ALERT_MULTIPLIER) &&
        !sBankLaunderAlertSent[enterpriseId])
    {
        sBankLaunderAlertSent[enterpriseId] = true;
        new alertText[192];
        format(alertText, sizeof(alertText),
            "Аномальный суточный оборот кассы предприятия #%d: %d USD. Требуется финансовая проверка.",
            Enterprise_GetDbId(enterpriseId), sBankDailyLaunderVolume[enterpriseId]);
        Organizations_SendFinancialAlert(0, Character_GetId(playerid), sBankDailyLaunderVolume[enterpriseId], alertText);
        SendClientMessage(playerid, COLOR_UI_WARNING,
            "Внимание: повышенный оборот кассы привлек внимание аналитиков ФБР и Минфина.");
    }
    return 1;
}

static stock Internal_OpenBankAccount(playerid)
{
    if (Character_HasBankAccount(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "У вас уже есть открытый банковский счет.");
        return 0;
    }
    if (!Internal_IsPlayerNearBankBranch(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Открыть счет можно только в отделении Центрального банка Сан-Андреаса.");
        return 0;
    }
    if (Character_GetCitizenship(playerid) != CITIZENSHIP_CITIZEN)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Банковский счет открывается только гражданам США при наличии SSN.");
        return 0;
    }

    new ssn[SSN_STRING_LENGTH];
    Character_GetSSN(playerid, ssn, sizeof(ssn));
    if (ssn[0] == EOS)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Для открытия счета необходим действующий номер социального страхования (SSN).");
        return 0;
    }
    if (Roles_HasPerk(Character_GetRoleId(playerid), PERK_FIRE_RESIST_50))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Религиозные убеждения вашего персонажа запрещают пользоваться банковской системой.");
        return 0;
    }
    if (!Internal_HasPassportWithSsn(playerid, ssn))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Для открытия счета предъявите паспорт с действующим номером SSN в потайном Слое 2.");
        return 0;
    }

    new iban[IBAN_STRING_LENGTH];
    Utils_GenerateIBAN(iban, sizeof(iban));
    Character_SetBankAccount(playerid, iban, 0, false, 0);

    if (DB_IsConnected())
    {
        new query[256];
        mysql_format(gMySQL, query, sizeof(query),
            "INSERT INTO `bank_accounts` (`iban`, `owner_char_id`, `balance_usd`, `is_frozen`) VALUES ('%e', %d, 0, 0);",
            iban,
            Character_GetId(playerid));
        mysql_tquery(gMySQL, query);
    }

    new const bool:cardIssued = (Internal_IssueBankCard(playerid) != 0);

    new msg[224];
    if (cardIssued)
    {
        format(msg, sizeof(msg),
            "Банковский счет успешно открыт. Ваш IBAN: %s. Дебетовая карта выдана в Слой 2.",
            iban);
    }
    else
    {
        format(msg, sizeof(msg),
            "Банковский счет успешно открыт. Ваш IBAN: %s. Для получения карты освободите место в Слое 2.",
            iban);
    }
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new details[160];
    format(details, sizeof(details), "Открытие банковского счета %s", iban);
    Audit_Log(Character_GetId(playerid), "BANK_OPEN", "BANK", "CHARACTER", 0, 0, details);
    return 1;
}

static stock bool:Internal_ParsePositiveInt(const input[], &outValue)
{
    outValue = 0;
    if (input[0] == EOS)
    {
        return false;
    }
    for (new i = 0, len = strlen(input); i < len; i++)
    {
        if (input[i] < '0' || input[i] > '9')
        {
            return false;
        }
        if (outValue > 200000000)
        {
            return false;
        }
        outValue = (outValue * 10) + (input[i] - '0');
    }
    return (outValue > 0);
}

// =============================================================================
//  4. ПУБЛИЧНЫЙ API БАНКА ДЛЯ ДРУГИХ МОДУЛЕЙ (Banking_*)
// =============================================================================

stock Banking_GetPhysicalCash(playerid, currency, cash_flag = CASH_FLAG_CLEAN)
{
    return Internal_CountCash(playerid, currency, cash_flag);
}

stock Banking_HasAccount(playerid)
{
    return Character_HasBankAccount(playerid);
}

stock Banking_IsFrozen(playerid)
{
    return Character_IsBankFrozen(playerid);
}

stock Banking_GetBalance(playerid)
{
    return Character_GetBankBalanceUsd(playerid);
}

stock bool:Banking_DebitAccount(playerid, amount, const reason[])
{
    if (!Character_IsLoaded(playerid) || amount <= 0)
    {
        return false;
    }
    if (!Character_HasBankAccount(playerid) || Character_IsBankFrozen(playerid))
    {
        return false;
    }
    if (Character_GetBankBalanceUsd(playerid) < amount)
    {
        return false;
    }

    Character_SetBankBalanceUsd(playerid, Character_GetBankBalanceUsd(playerid) - amount);

    if (DB_IsConnected())
    {
        new query[384];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `bank_accounts` SET `balance_usd` = `balance_usd` - %d WHERE `owner_char_id` = %d AND `balance_usd` >= %d AND `is_frozen` = 0;",
            amount,
            Character_GetId(playerid),
            amount);
        mysql_tquery(gMySQL, query);
    }

    Audit_Log(Character_GetId(playerid), "BANK_DEBIT", "BANK_ACCOUNT", "CASH", 0, amount, reason);
    return true;
}

stock bool:Banking_CreditAccount(playerid, amount, const reason[])
{
    if (!Character_IsLoaded(playerid) || amount <= 0)
    {
        return false;
    }
    if (!Character_HasBankAccount(playerid) || Character_IsBankFrozen(playerid))
    {
        return false;
    }

    Character_SetBankBalanceUsd(playerid, Character_GetBankBalanceUsd(playerid) + amount);

    if (DB_IsConnected())
    {
        new query[384];
        mysql_format(gMySQL, query, sizeof(query),
            "UPDATE `bank_accounts` SET `balance_usd` = `balance_usd` + %d WHERE `owner_char_id` = %d AND `is_frozen` = 0;",
            amount,
            Character_GetId(playerid));
        mysql_tquery(gMySQL, query);
    }

    Audit_Log(Character_GetId(playerid), "BANK_CREDIT", "CASH", "BANK_ACCOUNT", 0, amount, reason);
    return true;
}

// =============================================================================
//  5. АСИНХРОННЫЕ SQL-КОЛБЕКИ (forward / public)
// =============================================================================

forward OnBankStatementLoaded(playerid, sessionToken);
public OnBankStatementLoaded(playerid, sessionToken)
{
    if (!IsPlayerConnected(playerid) || !Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 0;
    }
    if (!Character_IsLoaded(playerid))
    {
        return 0;
    }

    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_INFO, "По вашему счету пока нет банковских операций.");
        return 1;
    }

    new body[BANK_STATEMENT_BUFFER_LEN];
    body[0] = '\0';
    strcat(body, "{FFC800}Последние банковские операции:{FFFFFF}\n\n", sizeof(body));

    for (new r = 0; r < rows; r++)
    {
        new actionType[33], details[160], createdAt[32];
        new amount = 0;
        cache_get_value_name(r, "action_type", actionType, sizeof(actionType));
        cache_get_value_name_int(r, "amount", amount);
        cache_get_value_name(r, "details", details, sizeof(details));
        cache_get_value_name(r, "created_at", createdAt, sizeof(createdAt));

        new amountStr[32];
        Utils_FormatMoney(amount, amountStr);

        new row[512];
        format(row, sizeof(row),
            "{FFFFFF}• %s | {66CC66}%s{FFFFFF} | %s\n  {88CCFF}%s{FFFFFF}\n",
            createdAt, amountStr, actionType, details);
        if ((strlen(body) + strlen(row)) >= sizeof(body))
        {
            break;
        }
        strcat(body, row, sizeof(body));
    }

    ShowPlayerDialog(
        playerid,
        DIALOG_BANK_STATEMENT,
        DIALOG_STYLE_MSGBOX,
        "{FFC800}Выписка по банковскому счету",
        body,
        "Понятно",
        "Закрыть");
    return 1;
}

forward OnBankTransferLookup(playerid, sessionToken, amount, const targetIban[]);
public OnBankTransferLookup(playerid, sessionToken, amount, const targetIban[])
{
    if (!IsPlayerConnected(playerid) || !Config_ValidatePlayerToken(playerid, sessionToken))
    {
        return 0;
    }
    if (!Character_IsLoaded(playerid) || amount <= 0)
    {
        return 0;
    }

    new rows = 0;
    cache_get_row_count(rows);
    if (rows <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR,
            "Получатель с указанным IBAN не найден в банковской системе.");
        return 1;
    }

    new targetAccId = 0, targetCharId = 0, targetBalance = 0, targetFrozen = 0;
    cache_get_value_name_int(0, "id", targetAccId);
    cache_get_value_name_int(0, "owner_char_id", targetCharId);
    cache_get_value_name_int(0, "balance_usd", targetBalance);
    cache_get_value_name_int(0, "is_frozen", targetFrozen);

    if (targetCharId <= 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Некорректный банковский счет получателя.");
        return 1;
    }
    if (targetCharId == Character_GetId(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Перевод самому себе невозможен.");
        return 1;
    }
    if (targetFrozen != 0)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Счет получателя заморожен. Перевод отклонен.");
        return 1;
    }
    if (Character_IsBankFrozen(playerid))
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "Ваш счет заморожен. Перевод невозможен.");
        return 1;
    }
    if (Character_GetBankBalanceUsd(playerid) < amount)
    {
        SendClientMessage(playerid, COLOR_UI_ERROR, "На вашем счете недостаточно средств для перевода.");
        return 1;
    }

    if (DB_IsConnected())
    {
        new query[512];
        mysql_format(gMySQL, query, sizeof(query),
            "START TRANSACTION; UPDATE `bank_accounts` SET `balance_usd` = `balance_usd` - %d WHERE `owner_char_id` = %d AND `balance_usd` >= %d AND `is_frozen` = 0; UPDATE `bank_accounts` SET `balance_usd` = `balance_usd` + %d WHERE `owner_char_id` = %d AND `is_frozen` = 0; COMMIT;",
            amount, Character_GetId(playerid), amount, amount, targetCharId);
        mysql_tquery(gMySQL, query);
    }

    Character_SetBankBalanceUsd(playerid, Character_GetBankBalanceUsd(playerid) - amount);

    new const targetPlayer = Internal_FindPlayerByCharId(targetCharId);
    if (targetPlayer != INVALID_PLAYER_ID && Character_IsLoaded(targetPlayer))
    {
        Character_SetBankBalanceUsd(targetPlayer, Character_GetBankBalanceUsd(targetPlayer) + amount);

        new targetMsg[192];
        format(targetMsg, sizeof(targetMsg),
            "На ваш банковский счет поступил перевод на сумму %d USD.",
            amount);
        SendClientMessage(targetPlayer, COLOR_UI_SUCCESS, targetMsg);
    }

    new amountStr[32], balanceStr[32];
    Utils_FormatMoney(amount, amountStr);
    Utils_FormatMoney(Character_GetBankBalanceUsd(playerid), balanceStr);

    new msg[224];
    format(msg, sizeof(msg),
        "Перевод %s по IBAN %s выполнен. Ваш баланс: %s.",
        amountStr, targetIban, balanceStr);
    SendClientMessage(playerid, COLOR_UI_SUCCESS, msg);

    new details[192];
    format(details, sizeof(details),
        "Перевод на IBAN %s, счет получателя #%d", targetIban, targetAccId);
    Audit_Log(Character_GetId(playerid), "BANK_TRANSFER", "BANK_ACCOUNT", "BANK_ACCOUNT",
        0, amount, details);
    return 1;
}

// =============================================================================
//  6. ХУКИ СИСТЕМНЫХ КОЛБЕКОВ (y_hooks)
// =============================================================================

hook OnGameModeInit()
{
    for (new i = 0; i < MAX_PLAYERS; i++)
    {
        sBankAction[i] = BANK_ACTION_NONE;
        sBankAmount[i] = 0;
        sBankExchangeFrom[i] = CURRENCY_USD;
        sBankExchangeTo[i] = CURRENCY_EUR;
        sBankTargetIban[i][0] = EOS;
        sBankMenuActionCount[i] = 0;
        sBankLaunderRowCount[i] = 0;
        sBankLaunderEnterprise[i] = INVALID_ENTERPRISE_ID;
        sBankLastCommandTick[i] = 0;
    }
    for (new e = 0; e < MAX_ENTERPRISES; e++)
    {
        sBankDailyLaunderVolume[e] = 0;
        sBankDailyLaunderDay[e] = 0;
        sBankLaunderAlertSent[e] = false;
    }
    printf("%s [Systems/Banking] Банковская система и обменные курсы инициализированы.",
        SERVER_LOG_PREFIX);
    return 1;
}

hook OnPlayerConnect(playerid)
{
    sBankAction[playerid] = BANK_ACTION_NONE;
    sBankAmount[playerid] = 0;
    sBankExchangeFrom[playerid] = CURRENCY_USD;
    sBankExchangeTo[playerid] = CURRENCY_EUR;
    sBankTargetIban[playerid][0] = EOS;
    sBankMenuActionCount[playerid] = 0;
    sBankLaunderRowCount[playerid] = 0;
    sBankLaunderEnterprise[playerid] = INVALID_ENTERPRISE_ID;
    sBankLastCommandTick[playerid] = 0;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    #pragma unused reason
    sBankAction[playerid] = BANK_ACTION_NONE;
    sBankAmount[playerid] = 0;
    sBankTargetIban[playerid][0] = EOS;
    sBankMenuActionCount[playerid] = 0;
    sBankLaunderRowCount[playerid] = 0;
    sBankLaunderEnterprise[playerid] = INVALID_ENTERPRISE_ID;
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DIALOG_BANK_MAIN:
        {
            if (!response || listitem < 0 || listitem >= sBankMenuActionCount[playerid])
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new E_BANK_ACTION:action = E_BANK_ACTION:sBankMenuAction[playerid][listitem];
            switch (action)
            {
                case BANK_ACTION_OPEN_ACCOUNT: Internal_OpenBankAccount(playerid);
                case BANK_ACTION_DEPOSIT: Internal_ShowDepositInput(playerid);
                case BANK_ACTION_WITHDRAW: Internal_ShowWithdrawInput(playerid);
                case BANK_ACTION_TRANSFER_IBAN: Internal_ShowTransferIbanInput(playerid);
                case BANK_ACTION_EXCHANGE: Internal_ShowExchangeMenu(playerid);
                case BANK_ACTION_STATEMENT: Internal_ShowStatement(playerid);
                case BANK_ACTION_LAUNDER: Internal_ShowLaunderMenu(playerid);
                case BANK_ACTION_CASH_INFO: Internal_ShowCashInfo(playerid);
                default: Internal_ShowMainMenu(playerid);
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_BANK_AMOUNT:
        {
            if (!response)
            {
                Internal_ShowMainMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new parsedAmount = 0;
            if (!Internal_ParsePositiveInt(inputtext, parsedAmount))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Введите корректную положительную сумму цифрами.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new const E_BANK_ACTION:action = E_BANK_ACTION:sBankAction[playerid];
            sBankAction[playerid] = BANK_ACTION_NONE;

            switch (action)
            {
                case BANK_ACTION_DEPOSIT: Internal_ExecuteDeposit(playerid, parsedAmount);
                case BANK_ACTION_WITHDRAW: Internal_ExecuteWithdraw(playerid, parsedAmount);
                default: SendClientMessage(playerid, COLOR_UI_ERROR, "Неизвестная банковская операция.");
            }
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_BANK_TRANSFER_IBAN:
        {
            if (!response)
            {
                Internal_ShowMainMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new iban[24];
            format(iban, sizeof(iban), "%s", inputtext);
            if (strlen(iban) != 20 || iban[0] != 'S' || iban[1] != 'A')
            {
                SendClientMessage(playerid, COLOR_UI_ERROR,
                    "Неверный формат IBAN. Ожидается 20 символов, начинающихся с SA.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            if (!DB_IsConnected())
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Банковская сеть временно недоступна.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            format(sBankTargetIban[playerid], 24, "%s", iban);
            Internal_ShowTransferAmountInput(playerid);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_BANK_TRANSFER_AMOUNT:
        {
            if (!response)
            {
                Internal_ShowMainMenu(playerid);
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new amount = 0;
            if (!Internal_ParsePositiveInt(inputtext, amount))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Введите корректную сумму перевода цифрами.");
                return Y_HOOKS_BREAK_RETURN_1;
            }

            new query[384];
            mysql_format(gMySQL, query, sizeof(query),
                "SELECT `id`, `owner_char_id`, `balance_usd`, `is_frozen` FROM `bank_accounts` WHERE `iban` = '%e' LIMIT 1;",
                sBankTargetIban[playerid]);
            mysql_tquery(gMySQL, query, "OnBankTransferLookup", "ddds",
                playerid,
                Config_GetPlayerSessionToken(playerid),
                amount,
                sBankTargetIban[playerid]);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_BANK_LAUNDER_LIST:
        {
            if (!response || listitem < 0 || listitem >= sBankLaunderRowCount[playerid])
            {
                sBankLaunderRowCount[playerid] = 0;
                return Y_HOOKS_BREAK_RETURN_1;
            }

            sBankLaunderEnterprise[playerid] = sBankLaunderRowMap[playerid][listitem];
            sBankAction[playerid] = BANK_ACTION_LAUNDER;

            new dirty = Internal_CountCash(playerid, CURRENCY_USD, CASH_FLAG_DIRTY);
            new dirtyStr[32];
            Utils_FormatMoney(dirty, dirtyStr);

            new body[320];
            format(body, sizeof(body),
                "Введите сумму грязных наличных USD для легализации.\n" \
                "Доступно в инвентаре: %s.\n" \
                "Налог составляет от 15%% до 25%% в зависимости от суммы.",
                dirtyStr);
            ShowPlayerDialog(
                playerid,
                DIALOG_BANK_LAUNDER_AMOUNT,
                DIALOG_STYLE_INPUT,
                "{FFC800}Легализация грязных наличных",
                body,
                "Легализовать",
                "Отмена");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_BANK_EXCHANGE_MENU:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }

            sBankLaunderRowCount[playerid] = 0;
            sBankAction[playerid] = BANK_ACTION_EXCHANGE;
            switch (listitem)
            {
                case 0:
                {
                    sBankExchangeFrom[playerid] = CURRENCY_USD;
                    sBankExchangeTo[playerid] = CURRENCY_EUR;
                }
                case 1:
                {
                    sBankExchangeFrom[playerid] = CURRENCY_EUR;
                    sBankExchangeTo[playerid] = CURRENCY_USD;
                }
                case 2:
                {
                    sBankExchangeFrom[playerid] = CURRENCY_USD;
                    sBankExchangeTo[playerid] = CURRENCY_CNY;
                }
                case 3:
                {
                    sBankExchangeFrom[playerid] = CURRENCY_CNY;
                    sBankExchangeTo[playerid] = CURRENCY_USD;
                }
                default:
                {
                    return Y_HOOKS_BREAK_RETURN_1;
                }
            }

            new fromName[32];
            Internal_GetCurrencyNameRu(sBankExchangeFrom[playerid], fromName, sizeof(fromName));
            new body[256];
            format(body, sizeof(body),
                "Введите сумму в валюте %s для обмена.\n" \
                "Банк выполняет обмен по действующему внутреннему курсу.",
                fromName);
            ShowPlayerDialog(
                playerid,
                DIALOG_BANK_EXCHANGE_AMOUNT,
                DIALOG_STYLE_INPUT,
                "{FFC800}Обмен валюты",
                body,
                "Обменять",
                "Отмена");
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_BANK_EXCHANGE_AMOUNT:
        {
            if (!response)
            {
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new amount = 0;
            if (!Internal_ParsePositiveInt(inputtext, amount))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Введите корректную сумму обмена цифрами.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ExecuteExchange(
                playerid,
                sBankExchangeFrom[playerid],
                sBankExchangeTo[playerid],
                amount);
            return Y_HOOKS_BREAK_RETURN_1;
        }

        case DIALOG_BANK_LAUNDER_AMOUNT:
        {
            if (!response)
            {
                sBankLaunderEnterprise[playerid] = INVALID_ENTERPRISE_ID;
                return Y_HOOKS_BREAK_RETURN_1;
            }
            new amount = 0;
            if (!Internal_ParsePositiveInt(inputtext, amount))
            {
                SendClientMessage(playerid, COLOR_UI_ERROR, "Введите корректную сумму легализации цифрами.");
                return Y_HOOKS_BREAK_RETURN_1;
            }
            Internal_ExecuteLaunder(playerid, sBankLaunderEnterprise[playerid], amount);
            return Y_HOOKS_BREAK_RETURN_1;
        }
    }
    return Y_HOOKS_CONTINUE_RETURN_1;
}

// =============================================================================
//  7. КОМАНДЫ (Pawn.CMD)
// =============================================================================

CMD:bank(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    new const nowTick = GetTickCount();
    if ((nowTick - sBankLastCommandTick[playerid]) < BANK_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Не так быстро: дождитесь завершения предыдущей операции.");
        return 1;
    }
    sBankLastCommandTick[playerid] = nowTick;
    Internal_ShowMainMenu(playerid);
    return 1;
}
alias:bank("atm");

CMD:cash(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    Internal_ShowCashInfo(playerid);
    return 1;
}

CMD:launder(playerid, params[])
{
    #pragma unused params
    if (!Character_IsLoaded(playerid))
    {
        return 1;
    }
    new const nowTick = GetTickCount();
    if ((nowTick - sBankLastCommandTick[playerid]) < BANK_COMMAND_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_UI_WARNING, "Не так быстро: дождитесь завершения предыдущей операции.");
        return 1;
    }
    sBankLastCommandTick[playerid] = nowTick;
    Internal_ShowLaunderMenu(playerid);
    return 1;
}
alias:launder("wash");
