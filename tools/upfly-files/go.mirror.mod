module upfly.tec.br/upfly-files

go 1.24.0

toolchain go1.24.7

require (
	github.com/gdamore/tcell/v2 v2.13.10
	github.com/rivo/uniseg v0.4.7
)

require (
	github.com/gdamore/encoding v1.0.1 // indirect
	github.com/lucasb-eyer/go-colorful v1.3.0 // indirect
	golang.org/x/sys v0.38.0 // indirect
	golang.org/x/term v0.37.0 // indirect
	golang.org/x/text v0.31.0 // indirect
)

// Espelhos oficiais no GitHub (golang.org pode estar bloqueado em alguns ambientes)
replace golang.org/x/sys => github.com/golang/sys v0.38.0

replace golang.org/x/term => github.com/golang/term v0.37.0

replace golang.org/x/text => github.com/golang/text v0.31.0

replace golang.org/x/tools => github.com/golang/tools v0.38.0

replace golang.org/x/mod => github.com/golang/mod v0.29.0

replace golang.org/x/sync => github.com/golang/sync v0.18.0

replace golang.org/x/net => github.com/golang/net v0.46.0

replace golang.org/x/telemetry => github.com/golang/telemetry v0.0.0-20251008203120-078029d740a8

replace golang.org/x/crypto => github.com/golang/crypto v0.43.0
