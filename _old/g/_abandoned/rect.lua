
function fit(w, h, box_w, box_h)
	if w / h > box_w / box_h
		return box_w, box_w * h / w
	else
		return box_h * w / h, box_h
	end
end

