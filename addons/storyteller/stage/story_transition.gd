@tool
class_name StoryTransition
extends Resource
## A named transition for backdrops and CGs, added to the built-in ones
## ("fade", "dissolve", "wipe_left", ...). Save one as a [code].tres[/code]
## file in [member StoryConfig.transition_folder] and tales use it by its
## file name: [code]backdrop("night", transition = "swirl")[/code]. Games
## can also list them in [member StoryConfig.transitions] or call
## [method StoryStage.add_transition].
##
## Without a [member shader], the transition reuses the built-in shader in
## [member mode], with its own [member mask], [member direction], and
## [member softness]: for example a "dissolve" that follows a swirl-shaped
## grayscale mask.
##
## With a [member shader], that canvas_item shader draws the whole
## transition. It receives the same uniforms as the built-in one and blends
## from the old picture to the new one as [code]progress[/code] goes from 0
## to 1: [code]from_tex[/code], [code]to_tex[/code] (sampler2D),
## [code]from_has_tex[/code], [code]to_has_tex[/code] (bool),
## [code]from_color[/code], [code]to_color[/code] (vec4),
## [code]from_size[/code], [code]to_size[/code], [code]screen_size[/code]
## (vec2), [code]progress[/code] (float), [code]mask_tex[/code], and
## [code]has_mask[/code]. Uniforms it does not declare are skipped.

enum Mode { CUT, FADE, DISSOLVE, WIPE, SLIDE }

## Built-in effect to use when there is no [member shader].
@export var mode := Mode.DISSOLVE
## For wipes and slides: the way the edge or the picture moves, in screen
## space (y points down).
@export var direction := Vector2.LEFT
## Grayscale picture for dissolves and wipes: darker areas change first.
@export var mask: Texture2D
## Width of the soft edge for dissolves and wipes, from 0 (hard) to 0.5.
@export_range(0.0, 0.5, 0.01) var softness := 0.08
## A shader that draws the whole transition instead of the built-in one.
@export var shader: Shader
## Extra uniform values for [member shader], by uniform name.
@export var parameters: Dictionary = {}
