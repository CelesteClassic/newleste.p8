# Summit Design for Newleste.p8

This document lists and talks about possible design choices and levels that should be added in the summit chapter for the newleste.p8 project.

# What will be the levels?

## Summary

- The levels will contain demakes of loved and memorable levels from Celeste (2018).
- Custom levels will also be added.
- There will be reworks of levels from Celeste (2018).

## Key Levels from Celeste (2018)

All the images are from [Berrycamp](https://berrycamp.github.io). Check out the maps on the website for the full levels.

### Early Summit-Specific Levels

These levels will have decent amount of horizontal scrolling but can be implemented without distribution/segmentation/shortening.
<img src="./summit_assets/celeste-summit-a_380x264.png" alt="a-02" />
<img src="./summit_assets/celeste-summit-a_664x184.png" alt="a-03" />
<img src="./summit_assets/celeste-summit-a_482x336.png" alt="a-04" />

### Summit-City Levels

Following levels also have some amount of vertical and horizontal scrolling but can still be implemented wihtout distribution/segmentation/shortening.

<br />

<img src="./summit_assets/celeste-summit-a_320x240.png" alt="b-00" />
<img src="./summit_assets/celeste-summit-a_632x440.png" alt="b-02" />
<img src="./summit_assets/celeste-summit-a_368x224.png" alt="b-05" />
<img src="./summit_assets/celeste-summit-a_1084x1208.png" alt="b-09" />

## Summit-Old-site Levels

C-01 and C-05, i.e. the second and the third image shown here, have significant amount of vertical scrolling in them.
This, hence, can cause a need to distribute/shorten/segment them arise but can be implemented with clever manipulation of space in the level and the levels in the carts.

<br />

<img src="./summit_assets/summit-oldsite-c-00.png" alt="c-00" />
<img src="./summit_assets/summit-oldsite-c-01.png" alt="c-01" />
In the following room, only the right-hand side room is to be made, the berry one. Instead of the berry, there will be a path to exit on top.
<img src="./summit_assets/summit-oldsite-c-05.png" alt="c-05" />
<img src="./summit_assets/summit-oldsite-c-09.png" alt="c-09" />

### Summit-Resort Levels

<img src="./summit_assets/summit-resort-d-01.png" alt="d-01" />
Following is a single screen level.
<img src="https://berrycamp.github.io/img/celeste/previews/summit/a/d-02.png" alt="d-02" />
<img src="./summit_assets/summit-resort-d-05.png" alt="d-05" />
<img src="./summit_assets/summit-resort-d-06.png" alt="d-06" />
Following is a single screen level.
<img src="https://berrycamp.github.io/img/celeste/previews/summit/a/d-09.png" alt="d-09" />
Following has a decent amount of scroll but can be implemented without too many hardships.
<img src="./summit_assets/summit-resort-d-10.png" alt="d-10" />
Following is a single screen level.
<img src="https://berrycamp.github.io/img/celeste/previews/summit/a/d-11.png" alt="d-11" />

### Summit-Ridge Levels

<img src="./summit_assets/summit-ridge-e-00.png" alt="e-00" />
<img src="./summit_assets/summit-ridge-e-03.png" alt="e-03" />
<img src="./summit_assets/summit-ridge-e-06.png" alt="e-06" />
<img src="./summit_assets/summit-ridge-e-07.png" alt="e-07" />
<img src="./summit_assets/summit-ridge-e-13.png" alt="e-13" />

### Summit-Reflection Levels

F-05, i.e. the second image, and the related rooms can take up a lot of space and hence might be hard to implement with other chapters.
Due to this, there arises a need to shorten, distribute and modify the rooms to fit the needs.

<img src="./summit_assets/summit-reflection-f-03.png" alt="f-03" />
<img src="https://berrycamp.github.io/img/celeste/previews/summit/a/f-05.png" alt="f-05" />

and the related rooms of it like f-06, 07, etc.

<img src="https://berrycamp.github.io/img/celeste/previews/summit/a/f-10.png" alt="f-10" />

This level has a significant amount of vertical scrolling and hence might have to be distributed into two rooms due to the already big F-05 and related rooms.

<img src="./summit_assets/summit-reflection-f-11.png" alt="f-11" />

### Summit-Specific Ending Levels

Due to the amount of scrolling required in these rooms, they are to be either shortened or be distributed if necessary.

<img src="./summit_assets/summit-end-01.png" alt="g-01" />
<img src="./summit_assets/summit-end-02.png" alt="g-02" />
<img src="./summit_assets/summit-end.png" alt="g-03" />

# Chapter Arc

Just like in City chapter, the summit should start with single screen levels with minimal-to-no scrolling and then gradullay grow to long, scrolling levels.
The chapter assumes knowledge of all the mechanics and hence only a single revision-like level will be given to each mechanic to brush up the memory.
That will be followed with 2-3 levels of testing that mechanic and in the end, testing all of them together.

# Layout

The Chapter follows the same layout as the whole game.
- It starts from summit-specific level introduction.
- It then follows the game's chapter progression, city to reflection.
- Then it ends with summit-specific levels where all the mechanics from previous chapters are merged.

# Cart Layout

Due to the scope and huge amount of material the Summit level needs, it will have to be distributed into different carts, i.e. Summit will itself be a multicart.

Following is one proposal of the content distribution into multiple carts, but as the project progresses, this may be subjected to change:
- Early Summit-Specific Levels, Summit-City, Summit-Old site
- Summit-Resort, Summit-Ridge
- Summit-Reflection, Summit-Specific Ending Levels
