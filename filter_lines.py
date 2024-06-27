def filter_lines_with_keyword(file_path, keyword_to_contain, keyword_not_to_contain):
    filtered_lines = []
    with open(file_path, 'r') as file:
        for line in file:
            if keyword_to_contain in line and keyword_not_to_contain not in line:
                filtered_lines.append(line.strip())  # Strip newline characters
    return filtered_lines

def save_lines_to_file(lines, output_file):
    with open(output_file, 'w') as file:
        for line in lines:
            file.write(line + '\n')

def main():
    file_path = input("Enter the path to the text file: ")
    keyword_to_contain = input("Enter the keyword to contain in lines: ")
    keyword_not_to_contain = input("Enter the keyword to not contian in lines: ")
    filtered_lines = filter_lines_with_keyword(file_path, keyword_to_contain, keyword_not_to_contain)
    output_file = input("Enter the path for the new text file to save filtered lines: ")
    save_lines_to_file(filtered_lines, output_file)
    print("Filtered lines containing the keyword '{}' have been saved to '{}'.".format(keyword_to_contain, output_file))

if __name__ == "__main__":
    main()