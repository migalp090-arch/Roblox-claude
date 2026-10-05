--!strict
-- Sonidos del juego. Se usan los sonidos que Roblox incluye en el cliente (rbxasset://) para que funcionen sin
-- subir nada. Para sonidos propios, sube los audios a tu cuenta y sustituye `Id` por "rbxassetid://NUMERO".
-- Volumen bajo a propósito: nada molesto ni fuerte.

export type SoundDef = { Id: string, Volume: number, Speed: number }

local Audio: { [string]: SoundDef } = {
	Select = { Id = "rbxasset://sounds/button.wav", Volume = 0.18, Speed = 1.6 },
	Move = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.35, Speed = 0.85 },
	Capture = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.55, Speed = 0.6 },
	Check = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Speed = 0.8 },
	Castle = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.4, Speed = 0.75 },
	Promote = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Speed = 1.3 },
	Win = { Id = "rbxasset://sounds/victory.wav", Volume = 0.35, Speed = 1 },
	Lose = { Id = "rbxasset://sounds/bass.mp3", Volume = 0.25, Speed = 0.8 },
	Draw = { Id = "rbxasset://sounds/switch.wav", Volume = 0.3, Speed = 0.8 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.12, Speed = 1.2 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.12, Speed = 0.6 },
}

return Audio
