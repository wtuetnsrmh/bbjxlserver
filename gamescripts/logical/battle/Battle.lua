local Battle = class("Battle")

function Battle:ctor(params)
	require("framework.api.EventProtocol").extend(self)

	self.frame = 2 / 60 * 1000	-- 固定帧时间间隔, 避免误差
	self.randomSeed = skynet.time()	-- 每场战斗的随机种子

	self.battleField = params.battleField
	params.battleField.battle = self

	self.actionNodes = {}
end

function Battle:init()
	self.battleStartTime = os.clock() * 1000

	self.battleField:init({ battle = self })

	-- 设置种子
	math.randomseed(self.randomSeed)
end

function Battle:pause(value)
	self.battleField:pause(value)
end

function Battle:schedule(diff)
	self.battleCurrentTime = os.clock() * 1000

	self.battleField:update(diff)

	if self.battleField:gameOver() then
		-- 所有士兵站立闲置
		self.battleField:standbyAllSoldiers()

		self:dispatchEvent({ name = "gameOver", starNum = self.battleField:calculateGameResult() })
	end
end

return Battle