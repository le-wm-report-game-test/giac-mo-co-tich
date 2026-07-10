# UI Review Current - Danh sach can thay doi

## Uu tien 1

- Chot 1 visual language thong nhat cho toan bo UI: button, panel, frame, icon, mau, font.
- Bo text song ngu, chot 1 ngon ngu hien thi thong nhat cho toan bo giao dien.
- Sua `VictoryDialog` va `DeathDialog` de cung he thiet ke voi `Main Menu` va `Settings`, khong de lech style.
- Bo emoji khoi UI, thay bang icon hoac ornament dong bo voi chat lieu co tich cua game.
- Chot bo quy tac trang tri UI theo huong co tich Viet: go son, vang cu, giay cuon, hoa van cach dieu; tranh panel flat generic.

## Uu tien 2

- Them ten boss tren boss HUD (`Chan Tinh`).
- Chinh orc counter thanh cach viet ro nghia hon, vi du `Orc da ha: 3/5`.
- Sua minimap de anchor theo viewport that, khong hardcode theo moc `1920`.
- Them phan biet icon tren minimap cho player, orc, boss, vat pham.
- Disable hoac ghi chu ro cho nut `Tiep tuc` khi chua co save.

## Uu tien 3

- Day cum button main menu xuong thap hon mot chut de tranh che logo/artwork.
- Giam size button main menu khoang 10-15% de background thoang hon.
- Them lop shadow/gradient nhe sau cum button main menu de tang do doc.
- Chinh loading screen bot generic, them motif rieng cua game.
- Dong bo progress bar loading voi visual khung button/hud.
- Viet lai loading tips theo giong co tich hon, bot chat system UI.

## Uu tien 4

- Chia settings thanh nhom ro hon: Hien thi, Am thanh, Dieu khien, Gameplay.
- Tach rieng `Che do man hinh` va `Do phan giai`, khong hardcode resolution trong label.
- Bo sung tuy chon: do nhay chuot, keybind, tat/bat rung camera, tat/bat hieu ung man hinh.
- Tang contrast text body trong mot so dropdown/settings item.
- Kiem tra lai responsive cua settings khi cua so nho hon `1920x1080`.

## Uu tien 5

- Neu chua co economy/exp that, bo reward block khoi victory dialog.
- Neu van giu reward, thay reward text/emoji bang icon asset dong bo.
- Them nut `Ve menu` vao death dialog.
- Can nhac them nut `Cai dat` trong death dialog.
- Chinh palette death dialog ve huong do-nau toi, tranh nut xanh la lech tong the.
- Them UI sound va motion thong nhat cho hover, click, open/close dialog.
