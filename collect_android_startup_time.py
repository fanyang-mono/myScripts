import os
from os.path import exists
import subprocess
import time
import re
import statistics

def getParams():
    package = input("Enter pakcage name: ")
    activity = input("Enter main activity name: ")
    adb = input("Enter the full path of adb: ")
    iterations = 10
    
    if not adb:
        adb = "/Users/yangfan/android-sdk/platform-tools/adb"
        if not exists(adb):
            adb = "adb"

    print(adb)
    # Clear some properties, so we don't accidentally hurt startup perf
    subprocess.call(adb + " shell setprop debug.mono.log 0", shell=True)
    subprocess.call(adb + " shell setprop debug.mono.profile 0", shell=True)
    # Clear window animations
    subprocess.call(adb + " shell settings put global window_animation_scale 0", shell=True)
    subprocess.call(adb + " shell settings put global transition_animation_scale 0", shell=True)
    subprocess.call(adb + " shell settings put global animator_duration_scale 0", shell=True)

    # Do an initial launch and leave the app on screen
    subprocess.call(adb + " shell am force-stop " + package, shell=True)
    subprocess.call(adb + " shell am start -n " + package + "/" + activity + " -W", shell=True)
    print("Keeping the app on screen for 10 seconds...")
    time.sleep(10)

    # We need a large logcat buffer
    subprocess.call(adb + " logcat -G 15M", shell=True)
    subprocess.call(adb + " logcat -c", shell=True)

    for x in range(iterations):
        subprocess.call(adb + " shell am force-stop " + package, shell=True)
        time.sleep(1)
        subprocess.call(adb + " shell am start -n " + package + "/" + activity + " -W", shell=True)
        time.sleep(3)

    cwd = os.getcwd()
    log = "log.txt"
    log_full_path = cwd + "/" + log
    if exists(log_full_path):
        os.remove(log_full_path)

    subprocess.call(adb + " logcat -d > " + log, shell=True)

    # Log message of the form:
    # 07-27 21:29:12.645  1451  1568 I ActivityTaskManager: Displayed com.companyname.mymauiapp/crc64bdb9c38958c20c7c.MainActivity: +746ms
    with open(log_full_path) as f:
        lines = f.readlines()
        cnt = 0
        kw = "ActivityTaskManager: Displayed"
        time_format = "(\d+s)*(\d+ms)+"
        sec_format = "\d+s"
        ms_format = "\d+ms"
        startup_times = []
        for index, line in enumerate(lines):
            if kw in line:
                time_str_raw = re.search(time_format, line)
                if time_str_raw:
                    print(line)
                    cnt = cnt + 1
                    time_str = time_str_raw.group(0)
                    t = 0
                    sec_str_raw = re.search(sec_format, time_str)
                    if sec_str_raw:
                        sec_str = sec_str_raw.group(0).replace("s", "")
                        t = t + int(sec_str) * 1000
                    ms_str_raw = re.search(ms_format, time_str)
                    if ms_str_raw:
                        ms_str = ms_str_raw.group(0).replace("ms", "")
                        t = t + int(ms_str)
                    print(t)
                    startup_times.append(t)
        if cnt != iterations:
            print("Found incorrect number of time recodes: " + str(cnt))
        else:
            print("Mean of startup time is % s " % (statistics.mean(startup_times)))
            print("Standard Deviation of startup time is % s " % (statistics.stdev(startup_times)))


def Main():
    getParams()

# now we are required to tell Python 
# for 'Main' function existence
if __name__=="__main__":
   Main()