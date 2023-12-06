local function print(s)
	mp.msg.info(s)
	mp.osd_message(s)
end

function tonar_menos()
    local arate = mp.get_property_number("audio-params/samplerate")
    local filter = string.format("asetrate=%d*(15/16)," ..
                                 "aresample=%d," ..
                                 "atempo=1/(15/16)", arate, arate)

    mp.command("af toggle " .. filter)
end

function tonar_mais()
    local arate = mp.get_property_number("audio-params/samplerate")
    local filter = string.format("asetrate=%d*(16/15)," ..
                                 "aresample=%d," ..
                                 "atempo=1/(16/15)", arate, arate)

    mp.command("af toggle " .. filter)
end

mp.add_key_binding(nil, "tone_increase", tonar_mais)
mp.add_key_binding(nil, "tone_decrease", tonar_menos)
