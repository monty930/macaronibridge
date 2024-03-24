# #!/bin/bash

# Check for the command line argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <config>"
    exit 1
fi

CONFIG_FILE="./SYSTEM/config/$1.conf"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found."
    exit 1
fi

# Reading the config file
TITLE=$(sed -n '1p' "$CONFIG_FILE")
AUTHOR=$(sed -n '2p' "$CONFIG_FILE")
FILE_IDS=$(sed -n '3p' "$CONFIG_FILE" | tr ',' ' ')

# Create a list of IDs to include
INCLUDE_IDS=()
for id_range in $FILE_IDS; do
    if [[ $id_range == *-* ]]; then
        IFS='-' read -ra RANGE <<< "$id_range"
        for i in $(seq ${RANGE[0]} ${RANGE[1]}); do
            INCLUDE_IDS+=($i)
        done
    else
        INCLUDE_IDS+=($id_range)
    fi
done

SOURCE_DIR="./source"
BUILD_DIR="./build"

OUTPUT_FILE="${BUILD_DIR}/$1.tex"

> "$OUTPUT_FILE"

declare -A file_groups

for file in "${SOURCE_DIR}"/*.tex; do
    if [ -f "$file" ]; then
        if [[ "$(basename "$file")" == "$1.tex" ]]; then
            continue
        fi

        file_id=$(sed -n 's/^%%% ID: \([0-9]*\)$/\1/p' "$file")
        if [[ ! " ${INCLUDE_IDS[@]} " =~ " ${file_id} " ]]; then
            continue
        fi

        priority=$(sed -n 's/^%%% PRIORITY: \([0-9]*\)$/\1/p' "$file")

        if [ -z "$priority" ]; then
            echo "Warning: No priority found in file '$file'. File will be ignored."
            continue
        fi

        file_groups[$priority]+="$file "
    fi
done

echo '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%' > "$OUTPUT_FILE"
echo '%%%%%%%%%%%%%%% This file has been generated automatically. %%%%%%%%%%%%%%%' >> "$OUTPUT_FILE"
echo '%%%%%%%%%%%%%%% Do not edit this file manually. %%%%%%%%%%%%%%%%%%%%%%%%%%%' >> "$OUTPUT_FILE"
echo '%%%%%%%%%%%%%%% See README for more information. %%%%%%%%%%%%%%%%%%%%%%%%%%' >> "$OUTPUT_FILE"
echo '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%' >> "$OUTPUT_FILE"
echo '' >> "$OUTPUT_FILE"
echo '\documentclass[12pt, a4paper]{report}' >> "$OUTPUT_FILE"
echo '\usepackage{titlesec}' >> "$OUTPUT_FILE"
echo '\titleformat{\chapter}' >> "$OUTPUT_FILE"
echo '    {\normalfont\huge\bfseries}{\thechapter}{1em}{}' >> "$OUTPUT_FILE"
echo '\usepackage{import}' >> "$OUTPUT_FILE"
echo '' >> "$OUTPUT_FILE"
echo '\import{../../lib/}{bridge.sty}' >> "$OUTPUT_FILE"
echo '\usepackage{hyperref}' >> "$OUTPUT_FILE"
echo '\hypersetup{' >> "$OUTPUT_FILE"
echo '    colorlinks=true,' >> "$OUTPUT_FILE"
echo '    linkcolor=blue,' >> "$OUTPUT_FILE"
echo '    filecolor=magenta,' >> "$OUTPUT_FILE"
echo '    urlcolor=cyan,' >> "$OUTPUT_FILE"
echo '}' >> "$OUTPUT_FILE"
echo '\setmainlanguage{english}' >> "$OUTPUT_FILE"
echo '' >> "$OUTPUT_FILE"
echo "\\title{$TITLE}" >> "$OUTPUT_FILE"
echo "\\author{$AUTHOR}" >> "$OUTPUT_FILE"
echo '\begin{document}' >> "$OUTPUT_FILE"
echo '\maketitle' >> "$OUTPUT_FILE"
echo '' >> "$OUTPUT_FILE"

TOC_FILE="${BUILD_DIR}/toc_entries.tex"
> "$TOC_FILE"

i=0

section_titles=("oneside" "competitive" "defensive")
section_result=("One side bidding" "Competitive bidding -- dealing with interference" "Defensive bidding -- how to overcall")
length=${#section_titles[@]}

echo '\begin{description}' >> "$OUTPUT_FILE"

for ((j=0; j<$length; j++)); do
    count=0

    section_for="${section_titles[$j]}"
    section_res="${section_result[$j]}"
    echo "--------------Working with section-----------------: $section_for"
    echo "\def\hyperlinkedchaptertitle{\hyperref[chap:$section_for]{\textbf{$((j+1)) $section_res}}}" >> "$OUTPUT_FILE"
    echo "\item[\hyperlinkedchaptertitle] \hfill \pageref{chap:$section_for}" >> "$OUTPUT_FILE"
    echo "\chapter{$section_res}\label{chap:$section_for}" >> "$TOC_FILE"

    for priority in $(echo "${!file_groups[@]}" | tr ' ' '\n' | sort -n); do
        for file in ${file_groups[$priority]}; do
            ((i++))
            title=$(sed -n 's/^%%% TITLE: \(.*\)$/\1/p' "$file")
            file_id=$(basename "$file" .tex)

            section=$(sed -n 's/^%%% SECTION: \(.*\)$/\1/p' "$file")

            if [ "$section" == "$section_for" ]; then
                echo "Section: $section"
                count=$((count+1))

                content=$(sed -n '/%%% SYSTEM BEGIN/,/%%% SYSTEM END/p' "$file" | sed '1d;$d')

                echo "\section{\texorpdfstring{$title}{$file_id}}\label{sec:$file_id}" >> "$TOC_FILE"
                echo "$content" >> "$TOC_FILE"
                echo '' >> "$TOC_FILE"

                echo "\def\hyperlinkedtitle{\hyperref[sec:$file_id]{\hspace{5mm}$((j+1)).${count}\, ${title}}}" >> "$OUTPUT_FILE"
                echo "\item[\hyperlinkedtitle] \hfill \pageref{sec:$file_id}" >> "$OUTPUT_FILE"
            else
                echo "Section not matched: $section"
            fi
        done
    done

done

echo '\end{description}' >> "$OUTPUT_FILE"
echo '\newpage' >> "$OUTPUT_FILE"

cat "$TOC_FILE" >> "$OUTPUT_FILE"

echo '\end{document}' >> "$OUTPUT_FILE"


cd "$SOURCE_DIR"

lualatex -interaction=batchmode --output-directory="../$BUILD_DIR" "$1.tex"
LUALATEX_STATUS=$?

cd ..

if [ $LUALATEX_STATUS -ne 0 ] || [ ! -f "$BUILD_DIR/$1.pdf" ]; then
    echo "Error: lualatex failed to create PDF. See log for details."
    exit 1
fi

cd "$SOURCE_DIR"

echo "Generating again for correct indexing..."

lualatex -interaction=batchmode --output-directory="../$BUILD_DIR" "$1.tex"
LUALATEX_STATUS=$?

cd ..

if [ $LUALATEX_STATUS -ne 0 ] || [ ! -f "$BUILD_DIR/$1.pdf" ]; then
    echo "Error: lualatex failed to create PDF. See log for details."
    exit 1
fi

mv "$BUILD_DIR/$1.pdf" "./SYSTEM/"

echo "PDF generated: $1.pdf"

