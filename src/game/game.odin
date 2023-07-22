package game

import "core:fmt"
import rand "core:math/rand"
import math "core:math/linalg/glsl"

import dm "../dmcore"

import "core:mem"

import globals "../dmcore/globals"


ColorGround : dm.color : { 71./255., 45./255., 60./255., 1 }
PlayerColor : dm.color : dm.WHITE
EnemyColor  : dm.color : dm.RED
WallColor   : dm.color : { 207./255., 198./255., 184./255., 1 }
GoldColor   : dm.color : { 244./255., 180./255., 27./255., 1 }

gameState: ^GameState

GameState :: struct {
    world: World,
    entities: dm.ResourcePool(Entity),

    playerHandle: EntityHandle,

    camera: dm.Camera,

    /// Assets
    atlas: dm.TexHandle,
    targetSprite: dm.Sprite,

    topWallSprite:      dm.Sprite,
    botWallSprite:      dm.Sprite,
    leftWallSprite:     dm.Sprite,
    rightWallSprite:    dm.Sprite,
    topLeftWallSprite:  dm.Sprite,
    topRightWallSprite: dm.Sprite,
    botLeftWallSprite:  dm.Sprite,
    botRightWallSprite: dm.Sprite,
    filledWallSprite:   dm.Sprite,

    font: dm.Font,

    /////////

    gold: int,
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)
    dm.InitResourcePool(&gameState.entities, 1024)

    gameState.camera = dm.CreateCamera(7, 4./3., 0.0001, 1000)
    gameState.camera.position.z = 1

    gameState.atlas = dm.LoadTextureFromFile("assets/atlas.png", globals.renderCtx)
    gameState.targetSprite = dm.CreateSprite(gameState.atlas, {16, 0, 16, 16})

    wallSprite := dm.CreateSprite(gameState.atlas, {16 * 3, 16, 16, 16})

    gameState.filledWallSprite = wallSprite

    wallSprite.atlasPos.y -= 16
    gameState.topWallSprite = wallSprite

    wallSprite.atlasPos.x -= 16
    gameState.topLeftWallSprite = wallSprite

    wallSprite.atlasPos.y += 16
    gameState.leftWallSprite = wallSprite

    wallSprite.atlasPos.y += 16
    gameState.botLeftWallSprite = wallSprite

    wallSprite.atlasPos.x += 16
    gameState.botWallSprite = wallSprite

    wallSprite.atlasPos.x += 16
    gameState.botRightWallSprite = wallSprite

    wallSprite.atlasPos.y -= 16
    gameState.rightWallSprite = wallSprite

    wallSprite.atlasPos.y -= 16
    gameState.topRightWallSprite = wallSprite

    // gameState.camera.orthoSize = f32(ChunkSize.x * WorldSize.x) / 2
    // gameState.camera.position = {
    //     -f32(WorldSize.x * ChunkSize.x) / 2,
    //     -f32(WorldSize.y * ChunkSize.y) / 2,
    //     -1
    // }

    gameState.font = dm.LoadFontSDF(globals.renderCtx, "assets/Kenney Pixel.ttf", 64)


    ////////////////////////////

    gameState.world = CreateWorld()
    for chunk in gameState.world.chunks {
        UpdateChunk(gameState.world, chunk)
    }

    player := CreatePlayerEntity()
    gameState.playerHandle = player.handle
    PutEntityInWorld(gameState.world, player)
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, auto_cast e.handle) == false {
            continue
        }

        ControlEntity(&e)
    }


    player := dm.GetElement(gameState.entities, auto_cast gameState.playerHandle)
    // assert(dm.IsHandleValid(gameState.entities, auto_cast gameState.playerHandle))

    gameState.camera.position.x = cast(f32) player.position.x
    gameState.camera.position.y = cast(f32) player.position.y
    // gameState.camera.position.x += dm.GetAxis(globals.input, .A, .D) * globals.time.deltaTime
    // gameState.camera.position.y += dm.GetAxis(globals.input, .S, .W) * globals.time.deltaTime
}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
    gameState = cast(^GameState) state

    player := dm.GetElement(gameState.entities, auto_cast gameState.playerHandle)

    @static selectedTile: ^Tile
    if dm.GetMouseButton(globals.input, .Left) == .JustPressed {
        mousePos := globals.input.mousePos
        normPos := dm.v2{f32(mousePos.x) / f32(globals.renderCtx.frameSize.x), 
                         f32(mousePos.y) / f32(globals.renderCtx.frameSize.y)} * 2 - 1

        camPos := gameState.camera.position
        camHeight := gameState.camera.orthoSize
        camWidth  := gameState.camera.aspect * camHeight

        worldPos := dm.v2{camPos.x, camPos.y} + normPos * {camWidth, -camHeight}
        worldPos = math.round(worldPos)

        selectedTile = GetWorldTile(gameState.world, {i32(worldPos.x), i32(worldPos.y)})
    }

    
    if dm.muiBeginWindow(globals.mui, "Game Debug", {globals.renderCtx.frameSize.x - 160, 0, 150, 120}, nil) {
        if dm.muiButton(globals.mui, "Refresh") {
            for chunk in gameState.world.chunks {
                UpdateChunk(gameState.world, chunk)
            }
        }

        if selectedTile != nil {
            dm.muiLabel(globals.mui, selectedTile.holdedEntity)
            dm.muiLabel(globals.mui, selectedTile.indestructible)
        }

        dm.muiEndWindow(globals.mui)
    }


    if player != nil {
        dm.DrawText(globals.renderCtx, 
                    fmt.tprint("Health: ", player.HP), 
                    gameState.font, 
                    {0, 0}, 32)

        dm.DrawText(globals.renderCtx, 
                    fmt.tprint("Gold: ", gameState.gold), 
                    gameState.font, 
                    {0, 32}, 32)
    }

    if debug {
        gameState.camera.orthoSize -= f32(globals.input.scroll)

        if dm.GetMouseButton(globals.input, .Right) == .Down {
            gameState.camera.position.xy -= cast([2]f32) dm.v2Conv(globals.input.mouseDelta) * 0.1
        }
    }
}


GetWallColor :: proc(tile: Tile) -> dm.color {
    if tile.indestructible {
        return dm.BLACK
    }
    else if tile.containsGold {
        return GoldColor
    }
    else {
        return WallColor
    }
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    dm.SetCamera(globals.renderCtx, gameState.camera)
    dm.ClearColor(globals.renderCtx, ColorGround)

    ctx := globals.renderCtx
    
    for chunk in gameState.world.chunks {
        for tile in chunk.tiles {
            if tile.isWall {
                assert(tile.sprite.texture.index != 0)
                dm.DrawSprite(ctx, tile.sprite, dm.v2Conv(tile.position), color = GetWallColor(tile))
            }
        }
    }

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, auto_cast e.handle) == false {
            continue
        }

        dm.DrawSprite(ctx, e.sprite, dm.v2Conv(e.position), color = e.tint)
        if .CanAttack in e.flags {
            dm.DrawSprite(ctx, gameState.targetSprite, dm.v2Conv(e.position + Dir(e.direction)))
        }
    }
}