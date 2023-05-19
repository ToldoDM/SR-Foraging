import os
import re

def rename_files(directory):
    # List all files in the directory
    files = os.listdir(directory)

    # Filter only .png files
    files = [file for file in files if file.endswith('.png')]

    # Extract number from filename using regex, then sort files by this number
    files.sort(key=lambda x: int(re.findall(r'\d+', x)[0]))

    # Create a counter
    i = 1

    # Loop through the files and rename them
    for file in files:
        new_file = f'frame_{i:010d}.png'
        os.rename(os.path.join(directory, file), os.path.join(directory, new_file))
        i += 1

# Use the function on your current directory
rename_files(os.getcwd())
