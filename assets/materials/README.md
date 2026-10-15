# Shop Surface Atlas

`shop_surfaces.png` was generated with the built-in image-generation tool for this
project on 2026-10-13. The original generated file is also preserved in the owner's
Codex generated_images folder. No existing art was overwritten.

The atlas quadrants are plaster (top-left), ceramic tiles (top-right), asphalt
(bottom-left) and paving (bottom-right). `shop_surface.gdshader` samples each region
using world-space coordinates and a material scale; the original bitmap is not
cropped or edited. It uses one texture sample, rough diffuse shading and works with
the project's Compatibility renderer.

## Generation Prompt

Create a production game-material texture atlas, square 2048 by 2048 if possible,
filling the whole image. Exactly four equal square quadrants with NO gutter, NO
borders, NO captions, NO letters, NO objects, NO perspective. These are four
straight-on flat orthographic seamless tileable surface textures for a polished
stylized Indian neighbourhood grocery-shop game, restrained natural surface
detail, not photorealistic: top-left cool off-white painted plaster with fine
subtle grain and gentle natural irregularities; top-right light cool-grey square
ceramic shop-floor tiles in a clean regular 4 by 4 grid with fine grey grout;
bottom-left charcoal asphalt with fine aggregate, no road markings and no cracks;
bottom-right pale grey concrete sidewalk paving tiles, clean regular 2 by 2 grid
with thin seams and soft aggregate. Uniform diffuse lighting with NO baked
directional highlights or shadows. Each quadrant individually tiles on all four
edges. Crisp subtle details readable at game scale. Do not make a scene or a
preview; just the flat four-texture atlas asset.
