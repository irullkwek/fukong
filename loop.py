import psutil
import subprocess
import time
import socket
import datetime

# Konfigurasi
THRESHOLD_PERCENTAGE = 50  # Batas CPU untuk menutup proses
INCLUDED_PROCESSES = ['CTFarm.exe']  # Proses yang dimonitor
COMPUTER_NAME = socket.gethostname()  # Nama komputer
LOG_FILE = f"{COMPUTER_NAME}.txt"  # File log sesuai dengan nama komputer
CHECK_INTERVAL = 5  # Interval pengecekan dalam detik (lebih sering agar responsif)

def log_cpu_usage(process_name, cpu_percent):
    """Mencatat penggunaan CPU ke dalam file log dengan timestamp."""
    try:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a") as f:
            f.write(f"[{timestamp}] {process_name} : {cpu_percent}%\n")
    except Exception as e:
        print(f"Logging error: {e}")

def terminate_process(process_name, pid):
    """Menghentikan proses berdasarkan PID dengan aman."""
    try:
        subprocess.run(['taskkill', '/F', '/PID', str(pid)], check=True)
        print(f"[INFO] Terminated process: {process_name} (PID: {pid})")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Failed to terminate {process_name} (PID: {pid}): {e}")

def monitor_processes():
    """Memantau dan menghentikan proses dengan CPU tinggi tanpa henti."""
    print("[INFO] Monitoring started...")
    
    while True:  # Loop berjalan terus tanpa henti
        try:
            processes_exceeded_threshold = False

            for process in psutil.process_iter(['name', 'pid']):
                try:
                    process_name = process.info['name']
                    process_pid = process.info['pid']

                    if process_name in INCLUDED_PROCESSES:
                        process_obj = psutil.Process(process_pid)
                        cpu_percent = process_obj.cpu_percent(interval=0.1)  # Cek CPU dengan cepat

                        if cpu_percent > THRESHOLD_PERCENTAGE:
                            print(f"[WARNING] High CPU Usage: {process_name} (PID: {process_pid}, CPU: {cpu_percent}%)")
                            terminate_process(process_name, process_pid)
                            log_cpu_usage(process_name, cpu_percent)

                        processes_exceeded_threshold = True

                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    continue  # Abaikan error dan lanjutkan

            if not processes_exceeded_threshold:
                print("[INFO] No high CPU processes detected.")

            time.sleep(CHECK_INTERVAL)  # Tunggu sebelum pengecekan ulang

        except Exception as e:
            print(f"[ERROR] Unexpected error: {e}")
            time.sleep(2)  # Jika error, tunggu sebentar lalu lanjutkan tanpa berhenti

if __name__ == "__main__":
    monitor_processes()
