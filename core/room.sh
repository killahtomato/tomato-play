# Shared-folder watch room setup and guest attachment.

# Create the mpv sync scripts for the selected room role. Reuse existing
# scripts so hosts and guests can safely join an already configured room.
room_bootstrap() {
    [ -n "$room_dir" ] || room_dir="$hist_dir/room"
    mkdir -p "$room_dir" 2>/dev/null || return 1
    export TP_ROOM_DIR="$room_dir"
    if [ ! -f "$room_dir/tp-room-host.lua" ]; then
        cat >"$room_dir/tp-room-host.lua" <<'LUA'
local d = os.getenv('TP_ROOM_DIR') or '.'
local f = d .. '/hoststate'
local function tick()
  local pos = mp.get_property_number('time-pos') or 0
  local paused = mp.get_property_bool('pause') or false
  local file = mp.get_property('path') or ''
  local h = io.open(f, 'w')
  if h then h:write(file .. '\n' .. string.format('%.2f', pos) .. '\n' .. tostring(paused) .. '\n') h:close() end
end
mp.add_periodic_timer(2, tick)
LUA
    fi
    if [ ! -f "$room_dir/tp-room-guest.lua" ]; then
        cat >"$room_dir/tp-room-guest.lua" <<'LUA'
local d = os.getenv('TP_ROOM_DIR') or '.'
local f = d .. '/hoststate'
local function tick()
  local h = io.open(f, 'r')
  if not h then return end
  local file = h:read('*l')
  local pos = tonumber(h:read('*l') or '0') or 0
  local paused = h:read('*l') == 'true'
  h:close()
  if paused then
    mp.set_property_bool('pause', true)
    return
  end
  mp.set_property_bool('pause', false)
  local p = mp.get_property_number('time-pos') or 0
  if math.abs(p - pos) > 4 then mp.commandv('seek', pos, 'absolute') end
end
mp.add_periodic_timer(1, tick)
LUA
    fi
    _room_flag="--script=$room_dir/tp-room-$room_role.lua"
}

# Prepare a guest and set local_path to the file advertised by its host.
# Return 1 for setup failure, 2 when no host state exists, and 3 when the host's
# file path is not visible from this machine.
room_join_prepare() {
    room_bootstrap || return 1
    [ -s "$room_dir/hoststate" ] || return 2
    local_path="$(head -n 1 "$room_dir/hoststate" 2>/dev/null)"
    [ -e "$local_path" ] || return 3
    return 0
}
