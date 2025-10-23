from __future__ import annotations

import json
from pathlib import Path
from tkinter import Button, Entry, Label, StringVar, Tk, filedialog, messagebox
from typing import Optional

from PIL import Image, ImageSequence


BASE_DIR = Path(__file__).resolve().parent

try:
    RESAMPLE_FILTER = Image.Resampling.LANCZOS  # type: ignore[attr-defined]
except AttributeError:  # pragma: no cover - older Pillow fallback
    RESAMPLE_FILTER = Image.LANCZOS


def export_frames(
    gif_path: Path,
    frames_dir: Path,
    file_pattern: str,
    target_height: int,
    target_width: Optional[int],
) -> int:
    frames_dir.mkdir(parents=True, exist_ok=True)

    frame_count = 0
    with Image.open(gif_path) as gif:
        for index, frame in enumerate(ImageSequence.Iterator(gif)):
            rgba_frame = frame.convert("RGBA")

            if target_width:
                resize_to = (target_width, target_height)
            else:
                width, height = rgba_frame.size
                new_width = int(width * (target_height / height))
                resize_to = (new_width, target_height)

            resized = rgba_frame.resize(resize_to, RESAMPLE_FILTER)
            output_filename = f"{file_pattern}{index}.png"
            resized.save(frames_dir / output_filename, "PNG")
            frame_count += 1

    return frame_count


def write_config(
    config_path: Path,
    *,
    gif_id: str,
    title: str,
    file_pattern: str,
    width: Optional[int],
    height: int,
    frame_count: int,
) -> None:
    config = {
        "id": gif_id,
        "displayName": title,
        "frameDirectory": "frames",
        "filePattern": file_pattern,
        "frameCount": frame_count,
        "frameExtension": "png",
        "frameSize": {"width": width, "height": height},
        "template": False,
        "metric": "cpu",
        "speedPolicy": {
            "type": "cpuLinear",
            "minInterval": 0.01,
            "maxInterval": 0.4,
        },
    }

    config_path.write_text(json.dumps(config, indent=2, ensure_ascii=False))


class App:
    def __init__(self, root: Tk) -> None:
        self.root = root
        self.root.title("Capoo GIF Generator")
        self.root.resizable(False, False)

        self.gif_path = StringVar()
        self.title = StringVar()
        self.gif_id = StringVar()
        self.file_pattern = StringVar()
        self.height = StringVar()
        self.width = StringVar()
        self.output_dir = StringVar()

        self._build_ui()

    def _build_ui(self) -> None:
        row = 0

        def add_label(text: str) -> Label:
            label = Label(self.root, text=text, anchor="w")
            label.grid(row=row, column=0, padx=10, pady=6, sticky="w")
            return label

        def add_entry(variable: StringVar, width: int = 40) -> Entry:
            entry = Entry(self.root, textvariable=variable, width=width)
            entry.grid(row=row, column=1, padx=10, pady=6, sticky="w")
            return entry

        add_label("GIF 路径：")
        add_entry(self.gif_path)
        Button(
            self.root,
            text="选择...",
            command=self.select_gif,
            width=10,
        ).grid(row=row, column=2, padx=10, pady=6, sticky="w")
        row += 1

        add_label("标题：")
        add_entry(self.title)
        row += 1

        add_label("ID：")
        add_entry(self.gif_id)
        row += 1

        add_label("filePattern：")
        add_entry(self.file_pattern)
        row += 1

        add_label("frameSize 高度：")
        add_entry(self.height)
        row += 1

        add_label("frameSize 宽度（选填）：")
        add_entry(self.width)
        row += 1

        add_label("输出目录名称：")
        add_entry(self.output_dir)
        row += 1

        Button(
            self.root,
            text="生成",
            command=self.generate,
            width=15,
        ).grid(row=row, column=1, padx=10, pady=12, sticky="w")

    def select_gif(self) -> None:
        path = filedialog.askopenfilename(
            title="选择 GIF 文件",
            filetypes=[("GIF 文件", "*.gif"), ("所有文件", "*.*")],
        )
        if path:
            self.gif_path.set(path)

    def generate(self) -> None:
        try:
            gif_path = self._require_path(self.gif_path.get(), "GIF 文件")
            title = self._require_text(self.title.get(), "标题")
            gif_id = self._require_text(self.gif_id.get(), "ID")
            file_pattern = self._require_text(self.file_pattern.get(), "filePattern")
            target_height = self._require_int(self.height.get(), "frameSize 高度")
            width_value = self.width.get().strip()
            target_width = self._optional_int(width_value, "frameSize 宽度") if width_value else None
            output_dir_name = self._require_text(self.output_dir.get(), "输出目录名称")

            output_dir = BASE_DIR / output_dir_name
            if output_dir.exists():
                raise ValueError("输出目录已存在，请更换名称。")

            frames_dir = output_dir / "frames"
            frames_dir.mkdir(parents=True, exist_ok=False)

            frame_count = export_frames(gif_path, frames_dir, file_pattern, target_height, target_width)

            write_config(
                output_dir / "config.json",
                gif_id=gif_id,
                title=title,
                file_pattern=file_pattern,
                width=target_width,
                height=target_height,
                frame_count=frame_count,
            )

            messagebox.showinfo("完成", f"生成成功：{output_dir}")
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("错误", str(exc))

    def _require_text(self, value: str, description: str) -> str:
        text = value.strip()
        if not text:
            raise ValueError(f"{description}不能为空。")
        return text

    def _require_int(self, value: str, description: str) -> int:
        text = value.strip()
        if not text:
            raise ValueError(f"{description}不能为空。")
        try:
            number = int(text)
        except ValueError as exc:
            raise ValueError(f"{description}必须为整数。") from exc
        return number

    def _optional_int(self, value: str, description: str) -> int:
        try:
            return int(value.strip())
        except ValueError as exc:
            raise ValueError(f"{description}必须为整数。") from exc

    def _require_path(self, value: str, description: str) -> Path:
        path = Path(value.strip())
        if not path.is_file():
            raise ValueError(f"{description}无效，请重新选择。")
        return path


def main() -> None:
    root = Tk()
    app = App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
