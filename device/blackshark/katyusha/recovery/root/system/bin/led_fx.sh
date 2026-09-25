#!/system/bin/sh
# Cosmetic only: while TWRP runs an operation (it logs "operation_start" / "operation_end"
# to /tmp/recovery.log), fade the back RGB light between random bright colours every 0.5 s,
# then fade back to the idle sky blue. Only writes LED sysfs files; all errors are ignored.

L1=/sys/devices/platform/soc/890000.i2c/i2c-4/4-0045/leds
L2=/sys/devices/platform/soc/988000.i2c/i2c-5/5-0045/leds
LOG=/tmp/recovery.log
IDLE_R=0 IDLE_G=100 IDLE_B=255

setc() {
    echo "$1" > $L1/red1/brightness
    echo "$2" > $L1/green1/brightness
    echo "$3" > $L1/blue1/brightness
    echo "$1" > $L2/red2/brightness
    echo "$2" > $L2/green2/brightness
    echo "$3" > $L2/blue2/brightness
} 2>/dev/null

# Random fully saturated colour: one channel 255, one 0, one random. Never dark.
pick() {
    x=$((RANDOM % 256))
    case $((RANDOM % 6)) in
        0) R=255 G=$x B=0 ;;
        1) R=$x G=255 B=0 ;;
        2) R=0 G=255 B=$x ;;
        3) R=0 G=$x B=255 ;;
        4) R=$x G=0 B=255 ;;
        *) R=255 G=0 B=$x ;;
    esac
}

# Fade from the current colour to R/G/B in 5 steps over 0.5 s.
fade() {
    for s in 1 2 3 4 5; do
        setc $((cr + (R - cr) * s / 5)) $((cg + (G - cg) * s / 5)) $((cb + (B - cb) * s / 5))
        sleep 0.1
    done
    cr=$R cg=$G cb=$B
}

cr=$IDLE_R cg=$IDLE_G cb=$IDLE_B
busy=0
while true; do
    # Last operation marker in the recent log; keep the previous state if none is visible.
    m=$(tail -n 2000 $LOG 2>/dev/null | grep -E "operation_(start|end)" | tail -n 1)
    case "$m" in
        *operation_start*) busy=1 ;;
        *operation_end*) busy=0 ;;
    esac
    if [ $busy = 1 ]; then
        pick
        fade
    elif [ $cr != $IDLE_R ] || [ $cg != $IDLE_G ] || [ $cb != $IDLE_B ]; then
        R=$IDLE_R G=$IDLE_G B=$IDLE_B
        fade
    else
        sleep 0.5
    fi
done
