local computer, component = require("computer"), require("component")

local minDensity, maxDensity, worldHeight, droppables, tools, computerEnergy, computerMaxEnergy, mathAbs, getComponent =
  2,
  10,
  -64,
  {
    cobblestone = 1,
    sandstone = 1,
    stone = 1,
    dirt = 1,
    gravel = 1,
    hardened_clay = 1,
    nether_brick = 1,
    sand = 1,
    soul_sand = 1,
    netherrack = 1,
  },
  {
    diamond_pickaxe = 1,
    iron_pickaxe = 1,
  },
  computer.energy,
  computer.maxEnergy,
  math.abs,
  function(c)
    c = component.list(c)()
    return c and component.proxy(c) or nil
  end

local robot, geolyzer, inventory_controller, generator =
  getComponent("robot"),
  getComponent("geolyzer"),
  getComponent("inventory_controller"),
  getComponent("generator")

local positionX, positionY, positionZ, rotation, inventorySize, robotSwing, robotSelect, geolyzerScan, inventory_controllerGetStackInInternalSlot = 0, 0, 0, 0, robot.inventorySize(), robot.swing, robot.select, geolyzer.scan, inventory_controller.getStackInInternalSlot

local turn, move = 
  function(clockwise)
    robot.turn(clockwise)
    rotation = rotation + (clockwise and 1 or -1)
    rotation = rotation > 3 and 0 or rotation < 0 and 3 or rotation
  end,
  function(direction)
    while true do
      local success, reason = robotSwing(direction)
      if success or reason == "air" then
        success, reason = robot.move(direction)
        if success then
          if direction == 0 or direction == 1 then
            positionY = positionY + (direction == 1 and 1 or -1)
          else
            positionX, positionZ = positionX + (rotation == 0 and 1 or rotation == 2 and -1 or 0), positionZ + (rotation == 1 and 1 or rotation == 3 and -1 or 0)
          end


          break
        end
      else
        if reason == "block" then
          while true do
            computer.beep(1500, 1)
          end
        end
      end
    end
  end

local function turnTo(requiredRotation)
  local difference = rotation - requiredRotation
  if difference ~= 0 then
    local fastestWay = difference > 2
    if difference <= 0 then
      fastestWay = -difference <= 2
    end

    while rotation ~= requiredRotation do
      turn(fastestWay)
    end
  end
end

local function moveTo(toX, toY, toZ)
  toX, toY, toZ = toX - positionX, toY - positionY, toZ - positionZ

  if toY ~= 0 then
    for i = 1, mathAbs(toY) do
      move(toY > 0 and 1 or 0)
    end
  end

  if toX ~= 0 then
    turnTo(toX > 0 and 0 or 2)
    for i = 1, mathAbs(toX) do
      move(3)
    end
  end

  if toZ ~= 0 then
    turnTo(toZ > 0 and 1 or 3)
    for i = 1, mathAbs(toZ) do
      move(3)
    end
  end
end

local function dropAll()
  print("Пиздую на базу")
  moveTo(0, 0, 0)

  print("Ищу сундук")
  for i = 0, 3 do
    local size = inventory_controller.getInventorySize(3)
    if size and size > 3 then
      print("Нашел, дропаю шмот")
      for j = 1, inventorySize do
        local stack = inventory_controllerGetStackInInternalSlot(j)
        if stack then
          robotSelect(j)
          robot.drop((droppables[stack.name] or droppables[stack.name:gsub("minecraft:", "")]) and 0 or 3)
        end
      end

      break
    else
      print("Чет пока не нашел")
      turn(true)
    end
  end
end

robotSelect(1)
move(0)

print("Детекчу сторону")
local initial = geolyzerScan(1, 0)[33]
for i = 0, 3 do
  if initial > 0 then
    if robot.swing(3) and geolyzerScan(1, 0)[33] == 0 then
      break
    end
  else
    if robot.place(3) and geolyzerScan(1, 0)[33] > 0 then
      break
    end
  end

  turn(false)
end

rotation = 0

while true do
  print("Сканирую")
  local scanX, scanZ, i, ores, scanResult, bedrock =
    positionX,
    positionZ,
    1,
    {},
    geolyzer.scan(
      positionX >= 0 and -(positionX % 8) or -7 + (-positionX % 8),
      positionZ >= 0 and -(positionZ % 8) or -7 + (-positionZ % 8),
      -1,
      8,
      8,
      1
    )

  for z = 0, 7 do
    for x = 0, 7 do 
      if scanResult[i] >= minDensity and scanResult[i] <= maxDensity then
        table.insert(ores, x - positionX)
        table.insert(ores, z - positionZ)
      elseif scanResult[i] < -0.4 then
        bedrock = true
        break
      end

      i = i + 1
    end
  end

  if bedrock or positionY <= worldHeight then
    print("Бедрок чет нашел на Y или низковато опустился", positionY - 1)
    break
  else
    print("Начинаю копать")
    move(0)

    if #ores > 0 then
      print("Нашел вот стока руд", #ores)
      while #ores > 0 do
        local nearestIndex, nearestDistance, distance = 1, math.huge
        for i = 1, #ores, 2 do
          distance = math.sqrt((ores[i] - positionX) ^ 2 + (ores[i + 1] - positionZ) ^ 2)
          if distance < nearestDistance then
            nearestIndex, nearestDistance = i, distance
          end
        end

        moveTo(scanX + ores[nearestIndex], positionY, scanZ + ores[nearestIndex + 1])
        
        for i = 1, 2 do
          table.remove(ores, nearestIndex)
        end
      end
    else
      print("Ни хуя тут руд нет")
    end
  end

  -- Чекаем генератор
  print("Чекаем генератор")
  if generator and generator.count() == 0 then
    print("Генератор пустой чота")
    for i = 1, inventorySize do
      robotSelect(i)
      if generator.insert() then
        print("Генератор заправлен")
        break
      end
    end
  end

  -- Чекаем инструмент
  print("Чекаем инстурмент")
  if robot.durability() <= 0.2 then
    print("Инструмент хуевый")
    for i = 1, inventorySize do
      local stack = inventory_controllerGetStackInInternalSlot(i)
      if stack and (tools[stack.name] or tools[stack.name:gsub("minecraft:", "")]) and stack.damage / stack.maxDamage < 0.8 then
        print("Ща сменю его")
        robotSelect(i)
        inventory_controller.equip()
        break
      end
    end
  end

  -- Чекаем зарядку и заполненность инвентаря
  print("Чекаю фри слоты или энергию", freeSlots, computerEnergy() / computerMaxEnergy())
  local freeSlots = 0
  for i = 1, inventorySize do
    if robot.count(i) == 0 then
      freeSlots = freeSlots + 1
    end
  end

  if freeSlots <= 4 or computerEnergy() / computerMaxEnergy() <= 0.2 then
    print("Чота все хуева")
    local oldX, oldY, oldZ, oldRotation = positionX, positionY, positionZ, rotation
    dropAll()

    while computerEnergy() / computerMaxEnergy() < 0.99 do
      print("Заряжаюсь", computerEnergy() / computerMaxEnergy())
      computer.pullSignal(1)
    end

    print("Пиздую назад")
    moveTo(oldX, oldY, oldZ)
    turnTo(oldRotation)
  end
end

dropAll()
turnTo(0)