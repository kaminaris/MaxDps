local INF = 2147483647;

function MaxDps:InitTTD(maxSamples, interval)
	self.ttd = {};
	self.ttd.Windows = maxSamples or 8; -- Max number of samples

	-- Code variables
	self.ttd.GUID = nil; -- Remember GUID of mob you are tracking
	self.ttd.MaxValue = 0; -- Remember max HP for relative shift
	self.ttd.Last = GetTime(); -- Remember last update
	self.ttd.Start = nil; -- First data collection time for relative shift
	self.ttd.Index = 0; -- Current ring buffer index
	self.ttd.Times = {}; -- Ring buffer data - data_x
	self.ttd.Values = {}; -- Ring buffer data - data_y
	self.ttd.Samples = 0; -- Number of collected (active) samples
	self.ttd.Estimate = nil; -- Estimated end time (not relative)
	self.ttd.TimeToDie = INF; -- Estimated end time relative

	self.ttd.Timer = self:ScheduleRepeatingTimer('TimeToDie', interval or 1.5);
end

function MaxDps:DisableTTD()
	if self.ttd.Timer then
		self:CancelTimer(self.ttd.Timer);
	end
end

function MaxDps:TimeToDie(target)
	target = target or 'target';

	-- Query current time (throttle updating over time)
	local now = GetTime();

	-- Current data
	local data = UnitHealth(target);

	-- Reset data?
	if data == UnitHealthMax(target) or not self.ttd.GUID or self.ttd.GUID ~= UnitGUID(target) then
		self.ttd.GUID = nil
		self.ttd.Start = nil
		self.ttd.Estimate = nil
	end

	-- No start time?
	if not self.ttd.Start or not self.ttd.GUID then
		self.ttd.Start = now;
		self.ttd.Index = 0;
		self.ttd.Samples = 0;
		self.ttd.MaxValue = UnitHealthMax(target) / 2;
		self.ttd.GUID = UnitGUID(target);
	end

	-- Remember current time
	self.ttd.Last = now;

	-- Save new data (Use relative values to prevent 'overflow')
	self.ttd.Values[self.ttd.Index] = data - self.ttd.MaxValue;
	self.ttd.Times[self.ttd.Index] = now - self.ttd.Start;

	-- Next index
	self.ttd.Index = self.ttd.Index + 1;

	-- Update number of active samples
	if self.ttd.Index > self.ttd.Samples then
		self.ttd.Samples = self.ttd.Index;
	end

	-- Using table as ring buffer
	if self.ttd.Index >= self.ttd.Windows then
		self.ttd.Index = 0;
	end

	-- Min number of samples
	if self.ttd.Samples >= 2 then
		-- Estimation variables
		local SS_xy, SS_xx, x_M, y_M = 0, 0, 0, 0;

		-- Calc pre-solution values
		for index = 0, self.ttd.Samples - 1 do
			-- Calc mean value
			x_M = x_M + self.ttd.Times[index] / self.ttd.Samples;
			y_M = y_M + self.ttd.Values[index] / self.ttd.Samples;

			-- Calc sum of squares
			SS_xx = SS_xx + self.ttd.Times[index] * self.ttd.Times[index];
			SS_xy = SS_xy + self.ttd.Times[index] * self.ttd.Values[index];
		end

		-- Few last additions to mean value / sum of squares
		SS_xx = SS_xx - self.ttd.Samples * x_M * x_M;
		SS_xy = SS_xy - self.ttd.Samples * x_M * y_M;

		-- Calc a_0, a_1 of linear interpolation (data_y = a_1 * data_x + a_0)
		local a_1 = SS_xy / SS_xx;
		local a_0 = (y_M - a_1 * x_M) + self.ttd.MaxValue;

		-- Find zero-point (Switch back to absolute values)
		local x = -(a_0 / a_1);

		-- Valid/Usable solution
		if a_1 and a_1 < 1 and a_0 and a_0 > 0 and x and x > 0 then
			self.ttd.Estimate = x + self.ttd.Start;
			-- Fallback
		else
			self.ttd.Estimate = nil;
		end

		-- Not enough data
	else
		self.ttd.Estimate = nil;
	end

	-- No/False information
	if not self.ttd.Estimate then
		self.ttd.TimeToDie = INF;
		-- Already over
	elseif now > self.ttd.Estimate then
		self.ttd.TimeToDie = 0;
	else
		self.ttd.TimeToDie = self.ttd.Estimate - now;
	end

	return self.ttd.TimeToDie;
end