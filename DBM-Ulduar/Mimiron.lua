local mod	= DBM:NewMod("Mimiron", "DBM-Ulduar")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20210427135121")

mod:SetCreatureID(33432)
mod:SetUsedIcons(7, 8)

mod:RegisterCombat("yell", L.YellPull)
mod:RegisterCombat("yell", L.YellHardPull)

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED",
	"CHAT_MSG_MONSTER_YELL",
	"SPELL_AURA_REMOVED",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"CHAT_MSG_LOOT",
	"SPELL_SUMMON"
)

local isMelee = select(2, UnitClass("player")) == "ROGUE"
	     or select(2, UnitClass("player")) == "WARRIOR"
	     or select(2, UnitClass("player")) == "DEATHKNIGHT"
		 or select(2, UnitClass("player")) == "PALADIN"
		 or select(2, UnitClass("player")) == "DRUID"


local blastWarn					= mod:NewTargetAnnounce(312790, 4)
local shellWarn					= mod:NewTargetAnnounce(312788, 2)
local lootannounce				= mod:NewAnnounce("MagneticCore", 1)
local warnBombSpawn				= mod:NewAnnounce("WarnBombSpawn", 3)
local warnFrostBomb				= mod:NewSpellAnnounce(64623, 3)

local warnShockBlast			= mod:NewSpecialWarning("WarningShockBlast", nil, false)
mod:AddBoolOption("ShockBlastWarningInP1", isMelee, "announce")
mod:AddBoolOption("ShockBlastWarningInP4", isMelee, "announce")
local warnDarkGlare				= mod:NewSpecialWarning("WarningSpinUp",true)

local enrage 					= mod:NewBerserkTimer(900)
local timerHardmode				= mod:NewTimer(607, "TimerHardmode", 312812)
local timerP1toP2				= mod:NewTimer(43, "TimeToPhase2")
local timerP2toP3				= mod:NewTimer(32, "TimeToPhase3")
local timerP3toP4				= mod:NewTimer(25, "TimeToPhase4")
local timerProximityMines		= mod:NewNextTimer(35, 63027)
local timerShockBlast			= mod:NewCastTimer(312792)
local timerSpinUp				= mod:NewCastTimer(4, 312794)
local timerDarkGlareCast		= mod:NewCastTimer(10, 63293)
local timerNextDarkGlare		= mod:NewNextTimer(41, 63293) -- Лазерный обстрел P3Wx2
local timerNextShockblast		= mod:NewNextTimer(34, 312792)
local timerPlasmaBlastCD		= mod:NewCDTimer(30, 312790)
local timerShell				= mod:NewTargetTimer(6, 312788)
local timerFlameSuppressant		= mod:NewCastTimer(59, 312793)
local timerNextFlameSuppressant	= mod:NewNextTimer(10, 312793)
local timerNextFlames			= mod:NewNextTimer(27.5, 312803)
local timerNextFrostBomb        = mod:NewNextTimer(30, 64623) --Ледяная бомба
local timerBombExplosion		= mod:NewCastTimer(15, 312804)
local timerNextRockets		    = mod:NewNextTimer(20, 63041) 

mod:AddBoolOption("PlaySoundOnShockBlast", isMelee)
mod:AddBoolOption("PlaySoundOnDarkGlare", true)
mod:AddBoolOption("HealthFramePhase4", true)
mod:AddBoolOption("AutoChangeLootToFFA", true)
mod:AddBoolOption("RangeFrame")
mod:AddBoolOption("YellOnblastWarn", true)
mod:AddBoolOption("YellOnshellWarn", true)

local hardmode = false
local phase						= 0 
local lootmethod, masterlooterRaidID

local spinningUp				= GetSpellInfo(312794)
local lastSpinUp				= 0
local is_spinningUp				= false
local napalmShellTargets = {}
local napalmShellIcon 	= 7

local function warnNapalmShellTargets()
	shellWarn:Show(table.concat(napalmShellTargets, "<, >"))
	table.wipe(napalmShellTargets)
	napalmShellIcon = 7
end

function mod:OnCombatStart(delay)
    hardmode = false
	enrage:Start(-delay)
	phase = 0
	is_spinningUp = false
	napalmShellIcon = 7
	self:NextPhase()
	timerPlasmaBlastCD:Start(20-delay)
	if DBM:GetRaidRank() == 2 then
		lootmethod, _, masterlooterRaidID = GetLootMethod()
	end
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(10)
	end
end

function mod:OnCombatEnd()
	DBM.BossHealth:Hide()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
	if self.Options.AutoChangeLootToFFA and DBM:GetRaidRank() == 2 then
		if masterlooterRaidID then
			SetLootMethod(lootmethod, "raid"..masterlooterRaidID)
		else
			SetLootMethod(lootmethod)
		end
	end
end

function mod:Flames()
	timerNextFlames:Start()
	self:ScheduleMethod(30, "Flames")
end

function mod:SPELL_SUMMON(args)
	if args:IsSpellID(63811, 63801, 312807) then -- Bomb Bot
		warnBombSpawn:Show()
	end
end


function mod:UNIT_SPELLCAST_CHANNEL_STOP(unit, spell)
	if spell == spinningUp and GetTime() - lastSpinUp < 3.9 then
		is_spinningUp = false
		self:SendSync("SpinUpFail")
	end
end

function mod:CHAT_MSG_LOOT(msg)
	-- DBM:AddMsg(msg) --> Meridium receives loot: [Magnetic Core]
	local player, itemID = msg:match(L.LootMsg)
	if player and itemID and tonumber(itemID) == 46029 then
		lootannounce:Show(player)
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(312792) then
		if phase == 1 and self.Options.ShockBlastWarningInP1 or phase == 4 and self.Options.ShockBlastWarningInP4 then
			warnShockBlast:Show()
		
		end
		if( GetLocale() == "frFR") then
			warnShockBlast:Show()
		end
		timerShockBlast:Start()
		timerNextShockblast:Start()
		if self.Options.PlaySoundOnShockBlast then
			PlaySoundFile("Sound\\Creature\\HoodWolf\\HoodWolfTransformPlayer01.wav")
		end
	end
	if args:IsSpellID(312790, 312791) then -- plasma blast
		timerPlasmaBlastCD:Start()
	end
	if self.Options.YellOnblastWarn and args:IsPlayer() then
		SendChatMessage(L.YellblastWarn, "SAY")
end
	if args:IsSpellID(312793) then
		timerFlameSuppressant:Start()
	end
	if args:IsSpellID(64623) then
		warnFrostBomb:Show()
		timerBombExplosion:Start()
		timerNextFrostBomb:Start()
	end
end

local spamShell = 0
function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(312435, 312788) and args:IsDestTypePlayer() then -- ����� �������
		napalmShellTargets[#napalmShellTargets + 1] = args.destName
		timerShell:Start()
		if self.Options.SetIconOnNapalm then
			self:SetIcon(args.destName, napalmShellIcon, 6)
			napalmShellIcon = napalmShellIcon - 1
		end
                if self.Options.YellOnshellWarn and args:IsPlayer() then
				SendChatMessage(L.YellshellWarn, "SAY")
		end
		self:Unschedule(warnNapalmShellTargets)
		self:Schedule(0.3, warnNapalmShellTargets)
	elseif args:IsSpellID(312790, 312791) then -- Plasma Blast
		blastWarn:Show(args.destName)
		self:SetIcon(args.destName, 8, 6)
	end
end

local function show_warning_for_spinup()
	if is_spinningUp then
		warnDarkGlare:Show()
		if mod.Options.PlaySoundOnDarkGlare then
			PlaySoundFile("Sound\\Creature\\HoodWolf\\HoodWolfTransformPlayer01.wav")
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(312789, 63667, 63027) then				-- mines
		timerProximityMines:Start()

	elseif args:IsSpellID(312794, 312441) then			-- Spinning UP (before Dark Glare)
		is_spinningUp = true
		timerSpinUp:Start()
		timerDarkGlareCast:Schedule(4)
		timerNextDarkGlare:Schedule(19)			-- 4 (cast spinup) + 15 sec (cast dark glare)
		DBM:Schedule(0.15, show_warning_for_spinup)	-- wait 0.15 and then announce it, otherwise it will sometimes fail
		lastSpinUp = GetTime()
	
	elseif args:IsSpellID(312793) then
		timerNextFlameSuppressant:Start()
	
	elseif args:IsSpellID(63041) then
		timernextrockets:Start()
	end

end

function mod:NextPhase()
	phase = phase + 1
	if phase == 1 then
		timerFlameSuppressant:Start()
		timerShockBlast:Start(30)
		if self.Options.HealthFrame then
			DBM.BossHealth:Clear()
			DBM.BossHealth:AddBoss(33432, L.MobPhase1)
		end

	elseif phase == 2 then
		timerNextShockblast:Stop()
		timerProximityMines:Stop()
		timerFlameSuppressant:Stop()
		timerP1toP2:Start()
		timerNextDarkGlare:Start(85)
		if self.Options.HealthFrame then
			DBM.BossHealth:Clear()
			DBM.BossHealth:AddBoss(33651, L.MobPhase2)
			
		end
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
		end
		if hardmode then
            timerNextFrostBomb:Start(114)
        end

	elseif phase == 3 then
		if self.Options.AutoChangeLootToFFA and DBM:GetRaidRank() == 2 then
			SetLootMethod("freeforall")
		end
		timerDarkGlareCast:Cancel()
		timerNextDarkGlare:Cancel()
		timerNextFrostBomb:Cancel()
		timerP2toP3:Start()
		if self.Options.HealthFrame then
			DBM.BossHealth:Clear()
			DBM.BossHealth:AddBoss(33670, L.MobPhase3)
		end

	elseif phase == 4 then
		if self.Options.AutoChangeLootToFFA and DBM:GetRaidRank() == 2 then
			if masterlooterRaidID then
				SetLootMethod(lootmethod, "raid"..masterlooterRaidID)
			else
				SetLootMethod(lootmethod)
			end
		end
		timerP3toP4:Start()
		if self.Options.HealthFramePhase4 or self.Options.HealthFrame then
			DBM.BossHealth:Show(L.name)
			DBM.BossHealth:AddBoss(33670, L.MobPhase3)
			DBM.BossHealth:AddBoss(33651, L.MobPhase2)
			DBM.BossHealth:AddBoss(33432, L.MobPhase1)
		end
		if hardmode then
			self:UnscheduleMethod("Flames")
			self:Flames()
            timerNextFrostBomb:Start(73)
        end
	end
end

do 
	local count = 0
	local last = 0
	local lastPhaseChange = 0
	function mod:SPELL_AURA_REMOVED(args)
		local cid = self:GetCIDFromGUID(args.destGUID)
		if GetTime() - lastPhaseChange > 30 and (cid == 33432 or cid == 33651 or cid == 33670) then
			if args.timestamp == last then	-- all events in the same tick to detect the phases earlier (than the yell) and localization-independent
				count = count + 1
				if (mod:IsDifficulty("heroic10") and count > 4) or (mod:IsDifficulty("heroic25") and count > 9) then
					lastPhaseChange = GetTime()
					self:NextPhase()
				end
			else
				count = 1
			end
			last = args.timestamp
		end
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellPhase2 or msg:find(L.YellPhase2) then
		--DBM:AddMsg("ALPHA: yell detect phase2, syncing to clients")
		self:SendSync("Phase2")	-- untested alpha! (this will result in a wrong timer)

	elseif msg == L.YellPhase3 or msg:find(L.YellPhase3) then
		--DBM:AddMsg("ALPHA: yell detect phase3, syncing to clients")
		self:SendSync("Phase3")	-- untested alpha! (this will result in a wrong timer)

	elseif msg == L.YellPhase4 or msg:find(L.YellPhase4) then
		--DBM:AddMsg("ALPHA: yell detect phase3, syncing to clients")
		self:SendSync("Phase4") -- SPELL_AURA_REMOVED detection might fail in phase 3...there are simply not enough debuffs on him

	elseif msg == L.YellHardPull or msg:find(L.YellHardPull) then
		timerHardmode:Start()
		timerFlameSuppressant:Start()
		enrage:Stop()
		hardmode = true
		timerNextFlames:Start(6.5)
		self:ScheduleMethod(6.5, "Flames")
	end
end


function mod:OnSync(event, args)
	if event == "SpinUpFail" then
		is_spinningUp = false
		timerSpinUp:Cancel()
		timerDarkGlareCast:Cancel()
		timerNextDarkGlare:Cancel()
		warnDarkGlare:Cancel()
	elseif event == "Phase2" and phase == 1 then -- alternate localized-dependent detection
		self:NextPhase()
	elseif event == "Phase3" and phase == 2 then
		self:NextPhase()
	elseif event == "Phase4" and phase == 3 then
		self:NextPhase()
	end
end