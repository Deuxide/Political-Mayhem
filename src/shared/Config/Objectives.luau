--!strict
-- Victory objective configurations.

export type Objectives = {
	HighStability: { threshold: number },
	HighVP: { threshold: number },
	-- Add more as needed
}

return {
	HighStability = { threshold = 80 },
	HighVP = { threshold = 10 },
}
