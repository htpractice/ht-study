Mastering *vi* (or *vim*) is essential for the *CKA exam*, as you will be editing YAML manifests directly in the terminal. Below is a curated list of shortcuts highly recommended for editing Kubernetes manifests efficiently.

### **Essential Modes**
*   **Command Mode (Default):** Used for navigation and issuing commands. Press `Esc` at any time to return here.
*   **Insert Mode (`i`):** Used to type text. Press `i` to start inserting at the cursor.

### **Navigation Shortcuts**
*   **`h`, `j`, `k`, `l`**: Left, Down, Up, Right (Use these instead of arrow keys to build muscle memory).
*   **`w` / `b`**: Jump forward/backward by a word.
*   **`G`**: Jump to the very end of the file.
*   **`gg`**: Jump to the beginning of the file.
*   **`0` (zero)**: Jump to the start of the current line.
*   **`$`**: Jump to the end of the current line.

### **Editing & Manipulation**
*   **`x`**: Delete the character under the cursor.
*   **`dw`**: Delete the current word.
*   **`dd`**: Delete (cut) the entire current line.
*   **`yy`**: Yank (copy) the entire current line.
*   **`p`**: Paste the yanked or deleted line below the cursor.
*   **`u`**: Undo the last action.
*   **`Shift + a`**: Move to the end of the line and enter *Insert Mode* (very handy for quick edits) (21:02).

### **Search & Replace**
*   **`/string`**: Search for a specific string (e.g., `/image`). Press `n` to find the next occurrence.
*   **`:set number`**: Display line numbers, which helps significantly with debugging YAML indentation errors.
*   **`:%s/old/new/g`**: Global search and replace (e.g., changing one image version to another throughout the entire file).

### **Saving & Exiting**
*   **`:wq`**: Write (save) and quit.
*   **`:q!`**: Quit without saving (use this if you make a mistake and want to start over).

### **CKA Exam Tip**
As the instructor demonstrates (20:13), you can often use `kubectl edit <resource-type> <resource-name>` to modify running objects. Getting comfortable with these shortcuts will save you significant time when adjusting `replicas` or `images` in a live cluster environment.