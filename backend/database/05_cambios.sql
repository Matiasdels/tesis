-- Migración 05: Tipo de evento Cambio de jugador
-- Convención: JugadorId = jugador que sale; JugadorRelacionadoId = jugador que entra.

INSERT INTO TiposEvento (Nombre) VALUES (N'Cambio');
