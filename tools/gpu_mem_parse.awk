# Разбор вывода gpumeminfo -o в TSV: unix_время тип total_KB mapped_KB count.
# Вход — блоки «### unix_время» и строки «тип: total N KB (...) mapped M KB (...) count:C».
/^### / { t = $2; next }
/: total/ {
    type = $1; sub(/:$/, "", type)
    total = ""; mapped = ""; count = ""
    for (i = 2; i <= NF; i++) {
        if ($i == "total") total = $(i + 1)
        else if ($i == "mapped") mapped = $(i + 1)
        else if ($i ~ /^count:/) { count = $i; sub(/^count:/, "", count) }
    }
    printf "%s\t%s\t%s\t%s\t%s\n", t, type, total, mapped, count
    fflush()
}
