#!/bin/bash

function print_and_save {
    echo $1
    echo $1 >> $2 
}  


report_f="report.txt"
rm -rf $report_f

print_and_save "------ Host ------" $report_f
hostname >> $report_f
hostname

# check OS familu
print_and_save "------ Check OS Family ------" $report_f
if lsb_release -a | grep Ubuntu; then
    lsb_release -a >> $report_f 2>&1
    print_and_save "*OS is Ubuntu." $report_f
elif cat /etc/redhat-release | grep CentOS; then
    cat /etc/redhat-release >> $report_f 2>&1
    print_and_save "*OS is CentOS." $report_f
else
    print_and_save "*Unknown OS." $report_f
fi


# check if python is installed and its version
print_and_save "------ Check Python ------" $report_f
python -V > report.dump 2>&1
python_stat=0
if grep Python report.dump; then
    cat report.dump >> $report_f
    if grep "Python 2.[7-9]" report.dump; then
        print_and_save "*Python version OK." $report_f
        python_stat=1
    elif grep "Python 3.*" report.dump; then
        print_and_save "*Python version OK." $report_f
        python_stat=2
    else 
        print_and_save "*Old Python version, need to update." $report_f
        python_stat=3
    fi
else
    print_and_save "*No Python installed" $report_f
    python_stat=4
fi

# check if Java is installed and its version
print_and_save "------ Check Java ------"  $report_f
java -version > report.dump 2>&1
java_stat=0
if grep java report.dump; then
    cat report.dump >> $report_f
    if grep "1.[7-8].*" report.dump; then
        echo "*Java version OK."
        print_and_save "*Java version OK."  $report_f
        java_stat=1
    else
        print_and_save "*Old Java version, need to update." $report_f 
        java_stat=2
    fi
else
    print_and_save "*No Java installed" $report_f
    java_stat=3
fi

print_and_save "------ Check scp ------" $report_f
if which scp; then
    print_and_save "*scp is installed." $report_f
else
    print_and_save "*scp is not installed." $report_f
fi

print_and_save "------ Check make ------" $report_f
if which scp; then
    print_and_save "*make is installed." $report_f
else
    print_and_save "*make is not installed." $report_f
fi

print_and_save "------ Check gcc ------" $report_f
if which gcc; then
    gcc --version >> $report_f
    print_and_save "*gcc is installed." $report_f
else
    print_and_save "*gcc is not installed." $report_f
fi

print_and_save "------ Check g++ ------" $report_f
if which g++; then
    g++ --version >> $report_f
    print_and_save "*g++ is installed." $report_f
else
    print_and_save "*g++ is not installed." $report_f
fi

print_and_save "------ Check CPU ------" $report_f
cat /proc/cpuinfo >> $report_f 2>&1

print_and_save "------ Check Memory ------" $report_f
free >> $report_f 2>&1

print_and_save "------ Check Disk ------" $report_f
df -h >> $report_f 2>&1
mount >> $report_f 2>&1

print_and_save "------ Check Network Interface ------" $report_f
ifconfig  >> $report_f 2>&1

print_and_save "------ Check Installed Libs ------" $report_f
ldconfig -p >> $report_f 2>&1

print_and_save "------ Check Installed Packages ------" $report_f
dpkg --get-selections >> $report_f 2>&1

echo -e "\n"
echo "Please check \"report.txt\" for more details."
