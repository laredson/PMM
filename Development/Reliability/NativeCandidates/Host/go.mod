module github.com/laredson/pmm-host

go 1.23

require pmm.local/supervision v0.0.0

replace pmm.local/supervision => ../Supervision

require pmm/uibridge v0.0.0

replace pmm/uibridge => ../UIBridge
