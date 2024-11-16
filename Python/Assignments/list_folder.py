import os


def list_of_files_in_folders(folder_path):
        try:
            files = os.listdir(folder_path)
            return files, None
        except FileNotFoundError:
            return None, " Please provide correct folder"
        except PermissionError:
            return None, " Permission Denied"

def main():
    folder_paths = input("Please provide some folder names space seperated : ").split()
    for folder_path in folder_paths:
        files, error_message = list_of_files_in_folders(folder_path)
        if files:
            print (f'Files in {folder_path}')
            for file in files:
                print (file)
        else:
            print(f"\nError in {folder_path}: {error_message}")

if __name__ == "__main__":
    main()
