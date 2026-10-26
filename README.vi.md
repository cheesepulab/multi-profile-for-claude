# Multi Profile for Claude

[English](README.md) · **Tiếng Việt**

Dùng nhiều tài khoản Claude cùng lúc trên Mac — công việc, cá nhân, khách hàng — mỗi tài khoản là một ứng dụng riêng với đăng nhập, cuộc trò chuyện và cài đặt riêng. Bạn cũng có thể tạo một lệnh terminal cho mỗi hồ sơ, ví dụ `claude-work`, để chạy Claude Code bằng tài khoản của hồ sơ đó.

[![Ủng hộ qua VietQR](https://img.shields.io/badge/%E1%BB%A6ng%20h%E1%BB%99-VietQR-2563EB)](DONATE.md#tieng-viet)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

https://github.com/user-attachments/assets/7d8ea541-c14d-4aa0-b710-5af52cd09661

Nếu video không phát được ở đây, hãy [xem trên YouTube](https://www.youtube.com/watch?v=W8z22g18PC8).

## Tính năng

- **Mỗi tài khoản một ứng dụng.** Mỗi hồ sơ là một ứng dụng Mac riêng (`Claude Work`, `Claude Personal`…) với biểu tượng Dock, mục Cmd-Tab, kết quả Spotlight và huy hiệu chữ cái có màu riêng. Mở bao nhiêu cái cùng lúc cũng được.
- **Ứng dụng Claude gốc giữ nguyên.** Nó trở thành hồ sơ "Default" và không bao giờ bị thay đổi.
- **Lệnh terminal.** `claude-work` mở Claude Code đã đăng nhập tài khoản Work; lệnh `claude` thông thường vẫn dùng tài khoản Default. Mọi tùy chọn của `claude` đều dùng được, ví dụ `claude-work -c`.
- **Chuyển hồ sơ từ thanh menu.** Xem hồ sơ nào đang chạy, đưa một hồ sơ lên trước, hoặc mở Claude Code của hồ sơ đó trong Terminal.
- **Hướng dẫn đăng nhập** để liên kết đăng nhập từ trình duyệt mở đúng hồ sơ.
- **Giao diện sáng và tối**, theo macOS hoặc tự chọn.
- **Riêng tư.** Không cần tài khoản, không thu thập dữ liệu, không gửi gì qua mạng. Mọi thứ nằm trên máy Mac của bạn.

## Cài đặt

Cần macOS 13 Ventura trở lên và [ứng dụng Claude cho máy tính](https://claude.ai/download) trong thư mục `/Applications`.

### Homebrew (khuyên dùng)

```bash
brew install --cask cheesepulab/tap/multi-profile-for-claude
```

Ứng dụng chưa được Apple công chứng (notarize) vì đây là dự án miễn phí, nên cask sẽ xóa cờ cách ly (quarantine) của tệp tải về sau khi cài. Bạn có thể đọc [cask](https://github.com/cheesepulab/homebrew-tap/blob/main/Casks/multi-profile-for-claude.rb) trước khi cài.

### Tải về

1. Tải tệp `Multi-Profile-for-Claude-<phiên bản>.zip` mới nhất từ [Releases](https://github.com/cheesepulab/multi-profile-for-claude/releases) và kéo ứng dụng vào `/Applications`.
2. Vì ứng dụng chưa được công chứng, macOS sẽ chặn lần mở đầu tiên. Hãy chạy
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Multi Profile for Claude.app"
   ```
   hoặc thử mở ứng dụng một lần, rồi vào **System Settings → Privacy & Security** và bấm **Open Anyway**.

### Tự build từ mã nguồn

Cần Xcode 16 trở lên (hoặc bộ command line tools có Swift 6).

```bash
git clone https://github.com/cheesepulab/multi-profile-for-claude.git
cd multi-profile-for-claude
scripts/install.sh
```

`install.sh` build ứng dụng và chép vào `~/Applications`. Ứng dụng tự build không bị cách ly nên mở được ngay, không có cảnh báo.

## Bắt đầu

1. Bấm biểu tượng hồ sơ trên thanh menu và chọn **New Profile…**.
2. Nhập tên (ví dụ "Work"), chọn màu và giữ ô **Also create a terminal command** được đánh dấu.
3. Chọn **Open and Sign In**. Trong lúc trợ lý đăng nhập đang mở, liên kết đăng nhập từ trình duyệt sẽ mở hồ sơ mới.
   - Nếu trình duyệt đang đăng nhập claude.ai bằng một tài khoản khác, hãy đăng xuất ở đó trước hoặc dùng cửa sổ ẩn danh.
   - macOS sẽ hỏi một lần xem hồ sơ có được dùng "Claude Safe Storage" không. Nhập mật khẩu máy Mac và chọn **Always Allow**.
4. Trong Terminal, chạy `claude-work` và đăng nhập Claude Code bằng cùng tài khoản đó.

## Cách hoạt động

- Ứng dụng của mỗi hồ sơ là một bản sao APFS của `Claude.app` đã cài, đặt trong `~/Applications/Claude Profiles`, nên gần như không tốn thêm dung lượng.
- Bản sao có bundle ID, tên hiển thị và biểu tượng riêng, cùng một trình khởi chạy nhỏ (`ProfileLauncher`) mở Claude với `--user-data-dir` trỏ tới thư mục của hồ sơ trong `~/Library/Application Support/MultiProfileForClaude/Profiles/<tên>/Desktop`.
- Vì bản sao đã bị chỉnh sửa, nó được ký lại kiểu ad-hoc cho riêng máy Mac của bạn. Các quyền (entitlement) chỉ hoạt động dưới chữ ký của nhà phát triển gốc sẽ bị bỏ ra.
- Lệnh terminal là các script nhỏ trong `~/.local/bin`, đặt `CLAUDE_CONFIG_DIR` thành `…/Profiles/<tên>/ClaudeCode` rồi chạy `claude` — đúng cách dùng nhiều tài khoản mà tài liệu của Claude Code mô tả.
- Trong lúc **Sign In…**, hồ sơ trở thành ứng dụng mở liên kết `claude://`. Liên kết sẽ trở về ứng dụng Claude gốc khi bạn xong, sau 10 phút, hoặc khi thoát ứng dụng.

## Nên biết

- **Cách đăng nhập trong ứng dụng hồ sơ:** đăng nhập bằng email và Google đều được. Passkey, khóa bảo mật phần cứng và Microsoft single sign-on cần chữ ký của ứng dụng gốc, nên hãy dùng chúng ở hồ sơ Default.
- **Sau khi Claude tự cập nhật,** các hồ sơ vẫn chạy bản cũ cho tới khi bạn build lại. Menu sẽ hiện thông báo **Rebuild**; đăng nhập và cuộc trò chuyện được giữ nguyên.
- **Hỏi quyền keychain sau khi build lại:** mỗi lần build lại tạo một chữ ký ad-hoc mới, nên macOS có thể hỏi lại quyền dùng "Claude Safe Storage".
- **`~/.local/bin` trong PATH:** trình cài Claude Code thường đã thêm sẵn. Nếu Terminal báo `command not found`, hãy thêm `export PATH="$HOME/.local/bin:$PATH"` vào `~/.zshrc`.

## Gỡ cài đặt

- Bằng Homebrew: `brew uninstall --cask multi-profile-for-claude` (thêm `--zap` để xóa luôn các ứng dụng hồ sơ và dữ liệu của chúng).
- Không dùng Homebrew, từ bản clone của repo này: `scripts/uninstall.sh` (thêm `--data` để xóa luôn dữ liệu hồ sơ).
- Từ trong ứng dụng: **Profiles → Remove All Profiles…** xóa mọi ứng dụng hồ sơ và lệnh terminal mà nó đã tạo.

Lệnh terminal chỉ bị xóa nếu có dòng `# Created by Multi Profile for Claude`, nên các script của riêng bạn không bao giờ bị đụng tới.

## Phát triển

```bash
swift build                     # build bản debug
swift test                      # chạy unit test
MPFC_INTEGRATION=1 swift test --filter IntegrationTests   # tạo, chạy rồi xóa một hồ sơ thử thật
scripts/build.sh                # dist/Multi Profile for Claude.app (universal)
scripts/release.sh 0.1.0        # tệp zip + cask Homebrew trong dist/, in ra các lệnh phát hành
```

Cài đặt của dự án (tài khoản GitHub, thông tin ủng hộ, bundle ID) nằm trong `scripts/config.sh`. Bản phát hành mặc định được ký ad-hoc. Để ký bằng chứng chỉ "Apple Development" miễn phí của Personal Team, chạy `scripts/signing-identities.sh` để xem team thật của từng chứng chỉ, rồi chép `scripts/config.local.sh.example` thành `scripts/config.local.sh` và điền `SIGN_IDENTITY`, `SIGN_TEAM_ID`. Quá trình build sẽ kiểm tra team của ứng dụng đã ký và dừng lại nếu không khớp.

## Ủng hộ

Multi Profile for Claude miễn phí. Nếu nó giúp bạn bớt phải đổi qua đổi lại tài khoản, bạn có thể **[ủng hộ dự án](DONATE.md#tieng-viet)**. Rất hoan nghênh báo lỗi và pull request.

## Giấy phép

[MIT](LICENSE)

---

Không liên kết với hay được Anthropic bảo trợ. Claude là nhãn hiệu của Anthropic, PBC.
