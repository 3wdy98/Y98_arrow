local ArrowGame = {}

-- الإعدادات
local config = {
    rounds = 5,           -- عدد الجولات الكلي
    arrowsPerRound = 4,   -- عدد الأسهم التي يجب الضغط عليها في كل جولة
    timeLimit = 10000,    -- الحد الزمني لكل جولة بالمللي ثانية
    cooldown = 500,       -- وقت الانتظار بين الجولات بالمللي ثانية
    arrowTypes = {
        'up',
        'down',
        'left',
        'right'
    }
}

-- متغيرات حالة اللعبة
local isActive = false
local currentRound = 0
local arrowSequence = {}
local playerSequence = {}
local timeStarted = 0
local gameOverCallback = nil
local successCallback = nil

-- حالة عرض الواجهة
local display = {
    showing = false
}

-- تسجيل أزرار الأسهم من الكيبورد
local function RegisterKeys()
    RegisterKeyMapping('+arrow_up', 'السهم للأعلى', 'keyboard', 'UP')
    RegisterKeyMapping('+arrow_down', 'السهم للأسفل', 'keyboard', 'DOWN')
    RegisterKeyMapping('+arrow_left', 'السهم لليسار', 'keyboard', 'LEFT')
    RegisterKeyMapping('+arrow_right', 'السهم لليمين', 'keyboard', 'RIGHT')
    
    RegisterCommand('+arrow_up', function() 
        if isActive then 
            HandleArrowPress('up') 
            -- إرسال الحدث إلى NUI لتسليط الضوء على الزر
            SendNUIMessage({
                action = 'keyPressed',
                direction = 'up'
            })
        end 
    end, false)
    
    RegisterCommand('+arrow_down', function() 
        if isActive then 
            HandleArrowPress('down') 
            SendNUIMessage({
                action = 'keyPressed',
                direction = 'down'
            })
        end 
    end, false)
    
    RegisterCommand('+arrow_left', function() 
        if isActive then 
            HandleArrowPress('left') 
            SendNUIMessage({
                action = 'keyPressed',
                direction = 'left'
            })
        end 
    end, false)
    
    RegisterCommand('+arrow_right', function() 
        if isActive then 
            HandleArrowPress('right') 
            SendNUIMessage({
                action = 'keyPressed',
                direction = 'right'
            })
        end 
    end, false)
    
    RegisterCommand('-arrow_up', function() end, false)
    RegisterCommand('-arrow_down', function() end, false)
    RegisterCommand('-arrow_left', function() end, false)
    RegisterCommand('-arrow_right', function() end, false)
end

-- إنشاء تسلسل عشوائي من الأسهم
local function GenerateArrowSequence()
    local sequence = {}
    for i = 1, config.arrowsPerRound do
        local randomIndex = math.random(1, #config.arrowTypes)
        table.insert(sequence, config.arrowTypes[randomIndex])
    end
    return sequence
end

-- معالجة الضغط على الأسهم
local function HandleArrowPress(direction)
    if not isActive then return end
    
    local currentIndex = #playerSequence + 1
    if currentIndex <= #arrowSequence then
        table.insert(playerSequence, direction)
        
        -- تسليط الضوء على السهم الذي تم الضغط عليه
        SendNUIMessage({
            action = 'highlightArrow',
            direction = direction,
            success = direction == arrowSequence[currentIndex]
        })
        
        -- التحقق من صحة السهم المضغوط
        if direction ~= arrowSequence[currentIndex] then
            -- سهم خاطئ، انتهاء اللعبة
            isActive = false
            SendNUIMessage({
                action = 'gameOver',
                success = false,
                reason = 'wrong_sequence'
            })
            SetNuiFocus(false, false)
            if gameOverCallback then
                gameOverCallback(false)
            end
            return
        end
        
        -- التحقق من اكتمال تسلسل الجولة
        if #playerSequence == #arrowSequence then
            -- زيادة عدد الجولات المنجزة
            currentRound = currentRound + 1
            
            -- التحقق من الانتهاء من جميع الجولات
            if currentRound >= config.rounds then
                -- اللعبة انتهت بنجاح
                isActive = false
                SendNUIMessage({
                    action = 'gameOver',
                    success = true
                })
                SetNuiFocus(false, false)
                if successCallback then
                    successCallback(true)
                end
                return
            end
            
            -- طباعة معلومات التصحيح
            print("تم إنهاء الجولة " .. currentRound .. " من " .. config.rounds)
            
            -- تجهيز الجولة التالية بتسلسل جديد
            Citizen.SetTimeout(config.cooldown, function()
                playerSequence = {} -- إعادة تعيين مدخلات اللاعب
                arrowSequence = GenerateArrowSequence() -- توليد تسلسل جديد
                timeStarted = GetGameTimer() -- إعادة ضبط المؤقت
                
                -- تحديث الواجهة للجولة الجديدة
                SendNUIMessage({
                    action = 'updateRound',
                    round = currentRound + 1,
                    totalRounds = config.rounds,
                    sequence = arrowSequence
                })
            end)
        end
    end
end

-- رد نداء NUI عند ضغط سهم من الواجهة
RegisterNUICallback('arrowPressed', function(data, cb)
    if isActive then
        HandleArrowPress(data.direction)
    end
    cb('ok')
end)

-- التحقق من تجاوز الحد الزمني
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if isActive and config.timeLimit > 0 then
            local elapsedTime = GetGameTimer() - timeStarted
            if elapsedTime > config.timeLimit then
                print("تم تجاوز الحد الزمني: " .. elapsedTime .. " مللي / " .. config.timeLimit .. " مللي")
                isActive = false
                SendNUIMessage({
                    action = 'gameOver',
                    success = false,
                    reason = 'timeout'
                })
                SetNuiFocus(false, false)
                if gameOverCallback then
                    gameOverCallback(false)
                end
            end
        end
    end
end)

-- تهيئة واجهة NUI
Citizen.CreateThread(function()
    RegisterKeys()
    SendNUIMessage({
        action = 'initialize'
    })
end)

-- بدء اللعبة
function ArrowGame.Start(options, onSuccess, onGameOver)
    if isActive then return false end
    
    -- دمج الخيارات الخاصة مع الإعدادات العامة
    if options then
        for k, v in pairs(options) do
            config[k] = v
        end
    end
    
    -- تعيين ردود النجاح والفشل
    successCallback = onSuccess
    gameOverCallback = onGameOver
    
    -- تهيئة الحالة
    isActive = true
    currentRound = 0
    playerSequence = {}
    arrowSequence = GenerateArrowSequence()
    timeStarted = GetGameTimer()
    
    print("بدء لعبة الأسهم بعدد جولات " .. config.rounds .. " وعدد أسهم " .. config.arrowsPerRound .. " في كل جولة")
    print("التسلسل المولد للجولة 1:", table.concat(arrowSequence, ", "))
    
    -- عرض واجهة اللعبة
    SendNUIMessage({
        action = 'startGame',
        round = currentRound + 1,
        totalRounds = config.rounds,
        sequence = arrowSequence,
        timeLimit = config.timeLimit
    })
    SetNuiFocus(true, false)
    
    display.showing = true
    return true
end

-- إيقاف اللعبة
function ArrowGame.Stop()
    if not isActive then return false end
    
    isActive = false
    SendNUIMessage({
        action = 'stopGame'
    })
    SetNuiFocus(false, false)
    
    display.showing = false
    return true
end

-- التحقق من حالة اللعبة
function ArrowGame.IsActive()
    return isActive
end

-- تصدير الكائن
exports('ArrowGame', function()
    return ArrowGame
end)

-- رد نداء NUI عند إغلاق اللعبة
RegisterNUICallback('gameClosed', function(data, cb)
    display.showing = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- أمر في الكونسول لتجربة اللعبة
RegisterCommand('testArrowGame', function()
    ArrowGame.Start({
        rounds = 5,
        arrowsPerRound = 4,
        timeLimit = 10000
    }, 
    function(success)
        print('تم إنهاء اللعبة بنجاح!')
    end, 
    function(failed)
        print('فشلت اللعبة!')
    end)
end, false)
