CONTENT_DIR="content"
OUTPUT_DIR="static"

get_mds() {
    find "$CONTENT_DIR" -type f -name "*.md"
}

while read input
do
    output="${input#*/}"
    output="$OUTPUT_DIR/${output%.md}.html"
    echo "Building $input => $output"
    mkdir -p "$(dirname "$output")" && pandoc -d default.yaml -o "$output" "$input"
done < <(get_mds)
