import tkinter as tk
from tkinter import ttk
import yaml

class YamlEditor:
    def __init__(self, root):
        self.root = root
        self.root.title("YAML Editor")

        self.tree = ttk.Treeview(root, columns=("Value",), show="headings")
        self.tree.heading("#1", text="Key")
        self.tree.heading("#2", text="Value")
        self.tree.pack(expand=tk.YES, fill=tk.BOTH)

        self.load_button = tk.Button(root, text="Load YAML", command=self.load_yaml)
        self.load_button.pack(pady=5)

        self.save_button = tk.Button(root, text="Save YAML", command=self.save_yaml)
        self.save_button.pack(pady=5)

        self.data = {}

    def load_yaml(self):
        file_path = tk.filedialog.askopenfilename(filetypes=[("YAML Files", "*.yaml;*.yml")])

        if file_path:
            with open(file_path, "r") as file:
                self.data = yaml.safe_load(file)

            self.display_data()

    def display_data(self):
        self.tree.delete(*self.tree.get_children())
        for key, value in self.data.items():
            self.tree.insert("", "end", values=(key, str(value)))

    def save_yaml(self):
        for child in self.tree.get_children():
            key = self.tree.item(child)["values"][0]
            value = self.tree.item(child)["values"][1]
            self.data[key] = value

        file_path = tk.filedialog.asksaveasfilename(defaultextension=".yaml", filetypes=[("YAML Files", "*.yaml;*.yml")])

        if file_path:
            with open(file_path, "w") as file:
                yaml.dump(self.data, file)

if __name__ == "__main__":
    root = tk.Tk()
    editor = YamlEditor(root)
    root.mainloop()