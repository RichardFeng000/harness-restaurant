extends RefCounted
## Artwork and the opening animation share the same final book bounds.

static func spread_rect(view_size: Vector2) -> Rect2:
	return Rect2(Vector2(18, 12), view_size - Vector2(36, 24))

static func left_page_rect(view_size: Vector2) -> Rect2:
	var spread := spread_rect(view_size)
	return Rect2(spread.position + spread.size * Vector2(0.078, 0.082), spread.size * Vector2(0.374, 0.818))

static func right_page_rect(view_size: Vector2) -> Rect2:
	var spread := spread_rect(view_size)
	return Rect2(spread.position + spread.size * Vector2(0.552, 0.082), spread.size * Vector2(0.362, 0.818))
