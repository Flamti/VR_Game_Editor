extends RefCounted

## Шифрованное хранилище секретов аккаунтов — `profiles/<id>/secrets.enc` (ADR-0011 п. 3).
##
## AES-256-CBC и HMAC-SHA256 по шифротексту (encrypt-then-MAC): в AESContext Godot 4.7 режима GCM
## нет, а CBC без MAC не отличает подменённый файл от своего. Ключи шифрования и MAC — разные,
## выводятся из корня метками HMAC. Корень — от PIN (profile/pin.gd, secret_root) или, у профиля
## без PIN, от секрета устройства (root_without_pin). Что это защищает и что нет —
## docs/design/user-profiles.md §7.
##
## Формат: MAGIC (5 байт) | IV (16) | шифротекст (кратен 16, PKCS#7) | MAC (32) по MAGIC|IV|шифротексту.

const MAGIC := "VRGS1"
const FILE := "secrets.enc"

## Фальсификатор «nomac»: MAC не сверяется — подменённый файл расшифровывается как свой.
static var falsify_no_mac := false


static func _key(root: PackedByteArray, label: String) -> PackedByteArray:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, root, label.to_utf8_buffer())


## Корень ключа у профиля без PIN: секрет устройства, разведённый по профилям.
static func root_without_pin(device_secret: PackedByteArray, profile_id: String) -> PackedByteArray:
	return _key(device_secret, "vrge-secrets:" + profile_id)


static func seal(root: PackedByteArray, data: Dictionary) -> PackedByteArray:
	var plain := JSON.stringify(data).to_utf8_buffer()
	var pad := 16 - plain.size() % 16
	for _i in pad:
		plain.append(pad)
	var iv := Crypto.new().generate_random_bytes(16)
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, _key(root, "enc"), iv)
	var ct := aes.update(plain)
	aes.finish()
	var out := MAGIC.to_utf8_buffer()
	out.append_array(iv)
	out.append_array(ct)
	out.append_array(Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _key(root, "mac"), out))
	return out


## Расшифровать. null — не наш формат, чужой ключ или подмена (MAC не сошёлся).
static func open(root: PackedByteArray, blob: PackedByteArray) -> Variant:
	var head := MAGIC.to_utf8_buffer()
	if blob.size() < head.size() + 16 + 16 + 32 or blob.slice(0, head.size()) != head:
		return null
	var body := blob.slice(0, blob.size() - 32)
	var mac := blob.slice(blob.size() - 32)
	var want := Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _key(root, "mac"), body)
	var diff := 0
	for i in 32:
		diff |= mac[i] ^ want[i]
	if diff != 0 and not falsify_no_mac:
		return null
	var iv := body.slice(head.size(), head.size() + 16)
	var ct := body.slice(head.size() + 16)
	if ct.size() == 0 or ct.size() % 16 != 0:
		return null
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, _key(root, "enc"), iv)
	var plain := aes.update(ct)
	aes.finish()
	var pad := plain[plain.size() - 1]
	if pad < 1 or pad > 16:
		return null
	var parsed: Variant = JSON.parse_string(plain.slice(0, plain.size() - pad).get_string_from_utf8())
	return parsed if parsed is Dictionary else null


static func save(dir: String, root: PackedByteArray, data: Dictionary) -> Error:
	var f := FileAccess.open(dir.path_join(FILE), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(seal(root, data))
	f.close()
	return OK


## Прочитать секреты профиля. Файла нет — пусто ({}); не открылся — null (чужой ключ, подмена).
static func load_from(dir: String, root: PackedByteArray) -> Variant:
	var path := dir.path_join(FILE)
	if not FileAccess.file_exists(path):
		return {}
	return open(root, FileAccess.get_file_as_bytes(path))
