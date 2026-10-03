--!strict
-- Punto de entrada del cliente: carga y arranca todos los controladores de ./Controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

Loader.Run(Loader.LoadChildren(script.Controllers), "Cliente")
