from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, Response
from starlette.middleware.base import BaseHTTPMiddleware
import psutil
import platform
import socket
import time

app = FastAPI()

# Custom CORS middleware — handles file:// null origins that standard CORSMiddleware blocks
class OpenCORSMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS":
            response = Response(status_code=204)
            response.headers["Access-Control-Allow-Origin"] = "*"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "*"
            return response
        response = await call_next(request)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "*"
        return response

app.add_middleware(OpenCORSMiddleware)

# Serve static files (dashboard)
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/server_dashboard")
def read_root():
    return FileResponse("static/index.html")

@app.get("/api/system")
def system_info():
    cpu_freq = psutil.cpu_freq()
    return {
        "hostname": socket.gethostname(),
        "os": platform.system(),
        "os_version": platform.version(),
        "cpu_percent": psutil.cpu_percent(interval=0.5),
        "cpu_cores": psutil.cpu_count(),
        "cpu_freq_mhz": round(cpu_freq.current, 1) if cpu_freq else 0,
        "uptime": psutil.boot_time(),
        "current_time": time.time(),
    }

@app.get("/api/memory")
def memory_info():
    mem = psutil.virtual_memory()
    swap = psutil.swap_memory()
    return {
        "total": mem.total,
        "used": mem.used,
        "available": mem.available,
        "percent": mem.percent,
        "swap_total": swap.total,
        "swap_used": swap.used,
        "swap_percent": swap.percent,
    }

@app.get("/api/disk")
def disk_info():
    disk = psutil.disk_usage('/')
    io = psutil.disk_io_counters()
    return {
        "total": disk.total,
        "used": disk.used,
        "free": disk.free,
        "percent": disk.percent,
        "read_bytes": io.read_bytes if io else 0,
        "write_bytes": io.write_bytes if io else 0,
    }

@app.get("/api/network")
def network_info():
    net = psutil.net_io_counters()
    addrs = psutil.net_if_addrs()
    active_iface = list(addrs.keys())[0] if addrs else "N/A"
    ip = addrs[active_iface][0].address if active_iface in addrs and addrs[active_iface] else "N/A"
    return {
        "bytes_sent": net.bytes_sent,
        "bytes_recv": net.bytes_recv,
        "packets_sent": net.packets_sent,
        "packets_recv": net.packets_recv,
        "ip_address": ip,
        "active_interface": active_iface,
    }

@app.get("/api/processes")
def process_info():
    processes = []
    for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'status']):
        try:
            info = proc.info
            if info['cpu_percent'] is None:
                info['cpu_percent'] = 0.0
            if info['memory_percent'] is None:
                info['memory_percent'] = 0.0
            processes.append(info)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    processes.sort(key=lambda x: x['cpu_percent'], reverse=True)
    return processes[:50]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)