--!strict
-- Punto de entrada del servidor: carga y arranca todos los servicios de ./Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

Loader.Run(Loader.LoadChildren(script.Services), "Servidor")
