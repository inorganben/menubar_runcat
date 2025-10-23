import json
from pathlib import Path

import flet as ft
from PIL import Image, ImageSequence


def export_frames(gif_path: Path, frames_dir: Path, file_pattern: str, target_height: int, target_width: int | None) -> int:
    """Export GIF frames as PNG files into frames_dir."""
    frames_dir.mkdir(parents=True, exist_ok=True)

    frame_count = 0
    with Image.open(gif_path) as gif:
        for index, frame in enumerate(ImageSequence.Iterator(gif)):
            rgba_frame = frame.convert("RGBA")

            # Resize to requested size. Height is required; width optional.
            if target_width:
                resize_to = (target_width, target_height)
            else:
                original_width, original_height = rgba_frame.size
                new_width = int(original_width * (target_height / original_height))
                resize_to = (new_width, target_height)

            resized = rgba_frame.resize(resize_to, Image.Resampling.LANCZOS)
            output_filename = f"{file_pattern}{index}.png"
            resized.save(frames_dir / output_filename, "PNG")
            frame_count += 1

    return frame_count


def write_config(config_path: Path, *, gif_id: str, title: str, file_pattern: str, width: int | None, height: int, frame_count: int, frame_directory: str = "frames") -> None:
    """Write config.json with the collected metadata."""
    config = {
        "id": gif_id,
        "displayName": title,
        "frameDirectory": frame_directory,
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


def main(page: ft.Page) -> None:
    base_dir = Path(__file__).resolve().parent
    page.title = "Capoo GIF Config Generator"
    page.horizontal_alignment = ft.CrossAxisAlignment.START
    page.vertical_alignment = ft.MainAxisAlignment.START

    selected_gif_path: list[str] = [""]

    def handle_file_picker_result(e: ft.FilePickerResultEvent) -> None:
        if e.files:
            selected_gif_path[0] = e.files[0].path or ""
            gif_path_display.value = selected_gif_path[0]
        else:
            selected_gif_path[0] = ""
            gif_path_display.value = "未选择文件"
        gif_path_display.update()

    file_picker = ft.FilePicker(on_result=handle_file_picker_result)
    page.overlay.append(file_picker)
    page.update()

    gif_path_display = ft.Text("未选择文件", selectable=True)

    title_input = ft.TextField(label="标题", autofocus=True)
    id_input = ft.TextField(label="ID")
    pattern_input = ft.TextField(label="filePattern", helper_text="例如：capoo-1-")
    height_input = ft.TextField(label="frameSize 高度", keyboard_type=ft.KeyboardType.NUMBER)
    width_input = ft.TextField(label="frameSize 宽度 (选填)", keyboard_type=ft.KeyboardType.NUMBER, hint_text="留空则在 JSON 中为 null")
    output_dir_input = ft.TextField(label="输出目录名称", helper_text="会在当前目录下创建")

    status_text = ft.Text("")

    def generate_clicked(_: ft.ControlEvent) -> None:
        status_text.value = ""
        status_text.color = ft.colors.BLACK
        page.update()

        try:
            gif_path = Path(selected_gif_path[0])
            if not gif_path.exists():
                raise ValueError("请选择一个有效的 GIF 文件。")

            title = title_input.value.strip()
            if not title:
                raise ValueError("标题不能为空。")

            gif_id = id_input.value.strip()
            if not gif_id:
                raise ValueError("ID 不能为空。")

            file_pattern = pattern_input.value.strip()
            if not file_pattern:
                raise ValueError("filePattern 不能为空。")

            height_value = height_input.value.strip()
            if not height_value:
                raise ValueError("frameSize 高度不能为空。")
            try:
                target_height = int(height_value)
            except ValueError as exc:
                raise ValueError("frameSize 高度必须为整数。") from exc

            width_value = width_input.value.strip()
            if width_value:
                try:
                    target_width = int(width_value)
                except ValueError as exc:
                    raise ValueError("frameSize 宽度必须为整数。") from exc
            else:
                target_width = None

            output_dir_name = output_dir_input.value.strip()
            if not output_dir_name:
                raise ValueError("输出目录名称不能为空。")

            output_dir = base_dir / output_dir_name
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

            status_text.value = f"生成成功！输出路径：{output_dir}"
            status_text.color = ft.colors.GREEN

        except Exception as exc:  # noqa: BLE001
            status_text.value = f"错误：{exc}"
            status_text.color = ft.colors.RED
        finally:
            status_text.update()

    generate_button = ft.ElevatedButton(text="生成", on_click=generate_clicked)
    pick_button = ft.ElevatedButton(
        text="选择 GIF",
        on_click=lambda _: file_picker.pick_files(
            allow_multiple=False,
            file_type=ft.FilePickerFileType.CUSTOM,
            allowed_extensions=["gif"],
        ),
    )

    page.add(
        ft.Column(
            controls=[
                ft.Row([pick_button, gif_path_display]),
                title_input,
                id_input,
                pattern_input,
                ft.Row([height_input, width_input]),
                output_dir_input,
                generate_button,
                status_text,
            ],
            tight=True,
            spacing=15,
        )
    )
    page.update()


if __name__ == "__main__":
    ft.app(target=main)
