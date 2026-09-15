# Разбор строк VrApi (logcat -v epoch) в TSV — см. tools/vrapi_log.sh.
/FPS=/ {
    t = $1
    line = $0; sub(/^.*VrApi *: */, "", line)
    fa = fd = st = asw = mhz = app = cg = pre = temp = gp = ""
    if (match(line, /FPS=[0-9]+\/[0-9]+/)) { split(substr(line, RSTART + 4, RLENGTH - 4), f, "/"); fa = f[1]; fd = f[2] }
    if (match(line, /Stale=[0-9]+/)) st = substr(line, RSTART + 6, RLENGTH - 6)
    if (match(line, /ASW=[^,]+/)) asw = substr(line, RSTART + 4, RLENGTH - 4)
    if (match(line, /[0-9]+\/[0-9]+MHz/)) { split(substr(line, RSTART, RLENGTH - 3), m, "/"); mhz = m[2] }
    if (match(line, /App=[0-9.]+ms/)) app = substr(line, RSTART + 4, RLENGTH - 6)
    if (match(line, /CPU&GPU=[0-9.]+ms/)) cg = substr(line, RSTART + 8, RLENGTH - 10)
    if (match(line, /Preempt=[0-9]+/)) pre = substr(line, RSTART + 8, RLENGTH - 8)
    if (match(line, /Temp=[0-9.]+C/)) temp = substr(line, RSTART + 5, RLENGTH - 6)
    if (match(line, /GPU%=[0-9.]+/)) gp = substr(line, RSTART + 5, RLENGTH - 5)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", t, fa, fd, st, asw, mhz, app, cg, pre, temp, gp, line
    fflush()
}
