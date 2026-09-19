extends RefCounted

## PIN профиля пользователя (ADR-0010, ADR-0011): 4–8 цифр, по желанию.
##
## Из PIN один раз выводится мастер — PBKDF2-HMAC-SHA256(PIN, соль, итерации), — а из мастера два
## независимых значения: хеш для проверки (хранится в профиле) и корень ключа секретов аккаунтов (не
## хранится нигде, живёт в памяти, пока профиль открыт). Хранить сам мастер или отдавать его в обе роли
## нельзя: тогда profile.cfg раскрыл бы ключ secrets.enc. PBKDF2 собран на `Crypto.hmac_digest`:
## готового в Godot 4.7 нет.
## Проверяется контрольными векторами (настольная проверка «PIN»): RFC 7914 §11 и сверенные с
## `hashlib.pbkdf2_hmac` Python, в том числе при ITERATIONS.
##
## Защита от перебора в шлеме — растущая задержка после ошибок. От перебора вынутого файла 4 цифры
## не защищают ничем — это записано в модели угроз (docs/design/user-profiles.md §7).

## Итерации PBKDF2. НЕ ИЗМЕРЕНО на шлеме: число выбрано так, чтобы на столе вход шёл десятки
## миллисекунд; цель — не дольше 300 мс на Quest, замер — строка самопроверки. Число хранится у
## каждого PIN, поэтому смена константы старые PIN не ломает.
const ITERATIONS := 10000
const MIN_LEN := 4
const MAX_LEN := 8
## После скольких ошибок подряд начинается задержка и с какой; дальше — удвоение до предела.
const FREE_FAILS := 3
const DELAY_MS := 1000
const DELAY_MAX_MS := 300000

## Фальсификатор «pinany»: сверка принимает любой PIN.
static var falsify_any := false


static func valid(pin: String) -> bool:
	if pin.length() < MIN_LEN or pin.length() > MAX_LEN:
		return false
	for c in pin:
		if c < "0" or c > "9":
			return false
	return true


static func make_salt() -> PackedByteArray:
	return Crypto.new().generate_random_bytes(16)


## PBKDF2-HMAC-SHA256, один блок (32 байта) — RFC 8018 §5.2.
static func derive(secret: PackedByteArray, salt: PackedByteArray, iterations: int) -> PackedByteArray:
	var crypto := Crypto.new()
	var block := salt.duplicate()
	block.append_array(PackedByteArray([0, 0, 0, 1]))
	var u := crypto.hmac_digest(HashingContext.HASH_SHA256, secret, block)
	var t := u.duplicate()
	for _i in range(1, iterations):
		u = crypto.hmac_digest(HashingContext.HASH_SHA256, secret, u)
		for j in t.size():
			t[j] = t[j] ^ u[j]
	return t


static func master(pin: String, salt: PackedByteArray, iterations: int) -> PackedByteArray:
	return derive(pin.to_utf8_buffer(), salt, iterations)


## Метки HMAC разводят две роли мастера.
static func _label(m: PackedByteArray, label: String) -> PackedByteArray:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, m, label.to_utf8_buffer())


## Хеш для проверки — то, что хранится в профиле.
static func verifier(m: PackedByteArray) -> PackedByteArray:
	return _label(m, "vrge-pin-verify")


## Корень ключа секретов аккаунтов (accounts/secret_box.gd) — не хранится.
static func secret_root(m: PackedByteArray) -> PackedByteArray:
	return _label(m, "vrge-secrets")


static func hash_pin(pin: String, salt: PackedByteArray, iterations: int) -> PackedByteArray:
	return verifier(master(pin, salt, iterations))


## Сравнение без раннего выхода: время не должно подсказывать, сколько байт совпало.
static func same(a: PackedByteArray, b: PackedByteArray) -> bool:
	if falsify_any:
		return true
	if a.size() != b.size():
		return false
	var diff := 0
	for i in a.size():
		diff |= a[i] ^ b[i]
	return diff == 0


static func matches(pin: String, salt: PackedByteArray, iterations: int, expected: PackedByteArray) -> bool:
	return same(hash_pin(pin, salt, iterations), expected)


## Сколько ждать после fails ошибок подряд, мс.
static func delay_ms(fails: int) -> int:
	if fails < FREE_FAILS:
		return 0
	return mini(DELAY_MS << mini(fails - FREE_FAILS, 20), DELAY_MAX_MS)
