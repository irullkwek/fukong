import os
import shutil
import subprocess
import pexpect
import sys

def main():
    # 1) Periksa dan hapus folder 'freeroot' jika ada
    if os.path.isdir("freeroot"):
        print("🗑️ Folder 'freeroot' sudah ada. Menghapus...")
        shutil.rmtree("freeroot", ignore_errors=True)
        if not os.path.exists("freeroot"):
            print("✅ Folder 'freeroot' berhasil dihapus.")
        else:
            print("❌ Gagal menghapus folder 'freeroot'.")
            return

    # 2) Mengkloning repositori
    print("🛠️ Mengkloning repositori freeroot...")
    try:
        subprocess.check_call(["git", "clone", "https://github.com/foxytouxxx/freeroot.git"])
    except subprocess.CalledProcessError as e:
        print(f"❌ Gagal mengkloning repositori freeroot. Kode keluar: {e.returncode}")
        return

    # Masuk ke direktori 'freeroot'
    try:
        os.chdir("freeroot")
    except Exception as e:
        print(f"❌ Error: Tidak dapat masuk ke direktori 'freeroot'. Detail: {e}")
        return

    # 3) Periksa arsitektur sistem
    print("🔍 Memeriksa arsitektur sistem...")
    try:
        arch = subprocess.check_output(["uname", "-m"]).decode().strip()
        print(f"📌 Arsitektur terdeteksi: {arch}")
    except Exception as e:
        print(f"❌ Gagal mendeteksi arsitektur: {e}")
        return

    # Hanya mendukung x86_64 atau aarch64
    if arch not in ["x86_64", "aarch64"]:
        print(f"❌ Arsitektur tidak didukung: {arch}.")
        return

    # 4) Atur izin eksekusi untuk root.sh
    print("🔧 Mengatur izin eksekusi untuk root.sh...")
    try:
        os.chmod("root.sh", 0o755)
        print("   ↳ Izin berhasil diatur.")
    except Exception as e:
        print(f"❌ Gagal mengatur izin: {e}")
        return

    # 5) Eksekusi 'root.sh' untuk pertama kali dan otomatis jawab 'YES'
    print("🔄 Menjalankan 'root.sh' untuk pertama kali...")
    print("   ↳ Proses ini dapat memakan waktu beberapa menit. Harap tunggu.")
    try:
        child = pexpect.spawn("bash root.sh", encoding="utf-8", timeout=600)
        child.logfile = sys.stdout  # Tampilkan keluaran secara real-time

        try:
            # Tunggu pertanyaan "Do you want to install Ubuntu? (YES/no): "
            child.expect(r"Do you want to install Ubuntu\? \(YES/no\): ", timeout=60)
            print("   ↳ Menjawab 'YES' untuk instalasi Ubuntu...")
            child.sendline("YES")
        except (pexpect.TIMEOUT, pexpect.EOF):
            print("❌ Error selama instalasi Ubuntu.")
            print("   ↳ Output terakhir yang diterima:")
            print(child.before)
            child.close()
            return

        try:
            # Tunggu hingga muncul "Mission Completed ! <----"
            child.expect(r"Mission Completed ! <----", timeout=600)
            print("   ↳ root.sh telah menyelesaikan instalasi.")
        except (pexpect.TIMEOUT, pexpect.EOF):
            print("❌ Error selama penyelesaian root.sh.")
            print("   ↳ Output terakhir yang diterima:")
            print(child.before)
            child.close()
            return

        if child.isalive():
            child.close()
            print("   ↳ root.sh selesai dengan sukses.")
        else:
            print("   ↳ root.sh berakhir secara tidak terduga.")

    except pexpect.ExceptionPexpect as e:
        print(f"❌ Gagal menjalankan root.sh dengan pexpect: {e}")
        return

    # 6) Periksa apakah /bin/sh ada di 'freeroot'
    bin_sh_path = os.path.join("bin", "sh")
    if os.path.exists(bin_sh_path):
        print("✅ /bin/sh ditemukan. Ubuntu berhasil diinstal di proot.")
    else:
        print("❌ /bin/sh tidak ditemukan. Instalasi Ubuntu mungkin gagal.")
        return

    # 6.1) Periksa jalur sebenarnya proot di dalam 'freeroot'
    # Biasanya terinstal di 'usr/local/bin/proot'
    proot_path = os.path.join(os.getcwd(), "usr/local/bin/proot")
    if not os.path.isfile(proot_path):
        print(f"❌ Proot tidak ditemukan di jalur yang diharapkan: {proot_path}")
        print("   Periksa bahwa 'root.sh' telah mengunduh biner proot dengan benar.")
        return

    # 7) Masuk ke PRoot secara interaktif, paksa locale=C
    print("🔑 Masuk ke PRoot dalam mode interaktif, paksa locale=C.")

    # Buat kamus dengan variabel lingkungan saat ini
    # dan paksa locale ke "C".
    locale_env = os.environ.copy()
    locale_env["LC_ALL"] = "C"
    locale_env["LANG"] = "C"
    locale_env["LANGUAGE"] = "C"

    try:
        subprocess.run([
            proot_path,          # Gunakan jalur absolut ke proot
            "--rootfs=.",
            "-0",
            "-w", "/root",
            "-b", "/dev",
            "-b", "/sys",
            "-b", "/proc",
            "-b", "/etc/resolv.conf",
            "--kill-on-exit",
            "bash", "-c", "cat /etc/shells && bash"
        ],
        check=True,
        env=locale_env  # Terapkan kamus dengan LC_ALL=C
        )
        print("✅ Perintah berhasil dijalankan di dalam PRoot.")
    except subprocess.CalledProcessError as e:
        print(f"❌ Kesalahan tak terduga saat menjalankan perintah tambahan di PRoot: {e}")
        print(f"   ↳ Kode keluar: {e.returncode}")
        return

    print("🎯 Instalasi dan konfigurasi selesai dengan sukses di proot.")

if __name__ == "__main__":
    main()
