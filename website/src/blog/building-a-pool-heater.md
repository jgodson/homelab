---
title: Building a Pool Heater
description: Piecing together a custom heater setup for my backyard pool
date: 2026-08-31
tags: 
  - hardware
  - esp32
  - home
  - automation
  - homeassistant
  - ai
  - 3dprinting
  - grafana
layout: post.njk
---

## Setting Up the Pool

This summer, I decided to purchase a pool for our backyard. The kids wanted one, I thought it sounded fun and I had watched a few YouTube videos on some... creative ways to heat them, so I figured why not! I first measured the spot in the backyard that I planned to put it. It looked fairly level and we had about 15' of room (we previously had the same size trampoline). So, we went to our local Walmart and purchased a 15' round pool and I set it up.

{% slideshow %}
  src/assets/images/pool-original.JPG, Filled pool as purchased
  src/assets/images/pool-inspection.JPG, Pool Inspector before filling, ensuring everything looks good
{% endslideshow %}

## Choosing a Heater

Where I live we have summers between 20-30 degrees celcius generally, but nights can be quite cool, down to ~10C or less. This means that the pool is not particularly warm, especially early in the day, even with a cover. I had intended to heat the pool in some form from the start, but I had to decide how. I have natural gas quick-connects in my backyard that I use for my barbecue and fire table, plus one unused connection that I thought would be perfect for this. The first idea I had from YouTube was a fire pit with copper tubing over the open flame. After checking the price on a length of said copper tubing ($100+) and considering it had to be an open flame, I decided against that one...

The other option I had seen on YouTube was using a tankless water heater. This seemed far safer and more legitimate. Several videos I watched used a portable propane heater. I could find the heater itself for around $100–$200, which wasn't bad. However, the thought of having to swap propane tanks constantly was not particularly appealing, so I focused my search on a natural gas version. Originally, I looked at an indoor power-vented version for around $400 and had planned to build a sort of shed for it. After looking into it some more, it turned out these need special exhaust kits that run about $300–$400 as well, so I decided to search some more. I ended up finding [this outdoor VEVOR unit](https://www.vevor.ca/water-heaters-c_12270/vevor-gas-tankless-water-heater-5-3gal-120000-btu-smart-temp-control-p_010266710623) for a similar price as the indoor unit. This was even better since it was designed to be outdoors and didn't require special venting at all.

Now to get everything hooked up, I ordered a [quick-connect gas hose](https://www.amazon.ca/dp/B0BJ1NWYWW), [pump](https://www.amazon.ca/dp/B0DBGZG23V), and a [high-temperature garden hose](https://www.amazon.ca/dp/B0BX6DWB1G) to go with it. I also planned to do some automation around when the pool was heated, so I ordered a [Kasa Outdoor Plug](https://www.amazon.ca/dp/B07M6RS2LC) that is Home Assistant compatible so I could start and stop the pump. This works perfectly with the tankless heater since it turns on and off with the flow of water.

{% image "./src/assets/images/heater-stand.JPG", "Tankless Heater hooked up to pump with custom built stand", "(min-width: 768px) 600px, 100vw" %}

Safety Disclaimer: Since this involves natural gas, anyone attempting something similar should follow the manufacturer's outdoor installation, clearance, and leak-testing requirements, as well as all local codes.

## Automating the Heater

The pump isn't meant to run continuously, so the plan was to figure out a reasonable on/off cycle for it. The Kasa has a built-in timer function that lets you run it for a set amount of time. This _was_ useful, however it required me to remember to turn it on and then set the timer to shut it off. The timing I decided on was 20 minutes on at a time and 5 minutes off. I found the pool could go from about 73°F to 85°F with around 8 hours of runtime from the heater doing this, which I was more than happy with.

Now, the problems were 1) automating the cycling and 2) stopping the heater when the pool got to a certain temperature. I didn't need a giant hot tub after all.

The first part was quite easy with just Home Assistant. I had Codex set up an automation to do the 20-minute-on, 5-minute-off cycle between 8 AM and 10 PM.

## Building the Temperature Sensor

Next, the temperature. I spent quite some time looking for a pre-built solution for this. And I did find an option that seemed like it would work well, but it was around $100 for the sensor and hub, plus would take a week to arrive. I've always enjoyed hardware tinkering too, so I thought, "what the heck, I can build this!" Of course, most electronic components come in bulk, so I ended up getting [3 ESP32s](https://www.amazon.ca/dp/B0D8T53CQ5), [5 temperature sensors](https://www.amazon.ca/dp/B0FLDRNB4R), a few tools, screws, heat-set inserts, and some weatherproof fittings. Overall it cost me more than $100... but that's just how it works sometimes, ya know? Plus I have enough for some extra projects now. For power, I had some CR123A batteries I had mistakenly bought a while ago and some steel clips from a project years ago, so I planned to incorporate those into the design.

## Designing the Enclosure

I needed an enclosure for it with a battery holder, a spot for the ESP32, and the board for the temp sensor, so I knew it was time to dust off the ole' 3D printer. I've designed things in Fusion 360 before, but this time I decided to try something different. I asked ChatGPT to design an enclosure. It took some measurements and a couple of test prints for the battery holder, but in the end I got something that was unexpectedly good and in a fraction of the time it would have taken me to do it entirely myself.

I had originally planned on doing just a pool temperature sensor, but since I had 5 temperature sensors I thought it might be nice to have an ambient temperature sensor too. It turned out that they only require a single GPIO pin (not that I was short on free pins).

I then decided that it would be nice to know battery life. I mentioned this to Codex and it told me how to build a voltage divider with some resistors and a capacitor. Luckily, these are things that I had some of already (again, from many, many years ago).

Now I had to figure out a nice way to put these in the case. I _could_ have used some premade boards I had and soldered the bits onto that, but that seemed unnecessary for the small amount of stuff this required. Surely 3D printing can also help here? Enter YouTube again. I found some videos of custom-made circuit boards that use raised bits and [copper tape](https://www.amazon.ca/dp/B09XD6R9XG) for connections. Heck yeah, that's cool! I ordered that immediately and asked ChatGPT to generate me an STL with raised traces and holes for the components.

{% slideshow %}
  src/assets/images/pool_voltage_divider_stl.png, Voltage Divider STL Preview
  src/assets/images/voltage-divider-1.JPG, Carefully applying and cutting copper tape
  src/assets/images/voltage-divider-2.JPG, Ready for components to be installed
  src/assets/images/voltage-divider-3.JPG, Questionable solder job
  src/assets/images/voltage-divider-4.JPG, Fully assembled and working
{% endslideshow %}

I had ChatGPT tweak the enclosure to add a spot for the custom circuit board and the final STL was ready to print.

{% image "./src/assets/images/pool_sensor_enclosure_stl.png", "Pool sensor enclosure STL preview", "(min-width: 768px) 600px, 100vw" %}

## Connecting ESPHome and Home Assistant

While the enclosure was printing, I hooked everything up to a breadboard and had ChatGPT get ESPHome running, configure the temperature sensors and the ESP32's sleep cycle to save power, and update the [Home Assistant automation](https://github.com/jgodson/homelab/blob/main/docker/home-assistant/automations.yaml) with two temperature setpoints to consider when starting the heater. The default mode heats the pool to 78°F between 8 AM and 10 PM, while "Pool Ready" mode increases the desired temperature to 85°F. ChatGPT also added a Home Assistant toggle that keeps the ESP32 awake, allowing us to perform over-the-air updates after it wakes from a sleep cycle. Once the enclosure was complete and running on battery power, I calibrated the voltage divider input and installed everything outside by the pool.


{% slideshow %}
  src/assets/images/completed-enclosure.JPG, All components added, ready for lid
  src/assets/images/enclosure-outside.JPG, Completed enclosure, mounted to pool leg
  src/assets/images/pool-sensor-and-intake.JPG, Pool temp sensor + 3D printed intake screen
{% endslideshow %}

## Monitoring It in Grafana

And of course, Home Assistant already exports all of this data to InfluxDB and I can query it from my Grafana instance, so it needed to be added to my [Home Assistant dashboard](https://github.com/jgodson/homelab/blob/main/k8s-configs/monitoring/grafana/dashboards/Home%20Assistant.json)!

{% image "./src/assets/images/grafana-pool-dashboard.jpg", "Home Assistant dashboard showing pool and outdoor temperatures, plus pump runtime", "(min-width: 768px) 600px, 100vw" %}

## The Result

{% image "./src/assets/images/heated-pool.JPG", "Pool, but now warmed", "(min-width: 768px) 600px, 100vw" %}

This was a lot of fun to build and get set up! I only get about 5 days from the two CR123A batteries, which is less than I had hoped, so I've already had ChatGPT design a new enclosure that uses four AA batteries so I can use rechargeable ones. Potentially I can tweak the awake and sleep times to get an extra couple of days out of it as well, but overall it was a great success! Now if only my kids actually used the pool like they said they were going to...

Until next time, keep on building!
