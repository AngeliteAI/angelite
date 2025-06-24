export function load({ params }) {
  // Return the articles data to be used in the layout
  return {
    articles: [
      {
        title: "Outpost Discovery",
        content:
          "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam in dui mauris. Vivamus hendrerit arcu sed erat molestie vehicula. Sed auctor neque eu tellus rhoncus ut eleifend nibh porttitor.",
        image: "https://picsum.photos/id/1/600/400",
        size: { cols: 3, rows: 3 },
        priority: 1, // Hero article (highest priority)
      },
      {
        title: "Space Exploration",
        content:
          "Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Cras mattis consectetur purus sit amet fermentum.",
        image: "https://picsum.photos/id/2/600/400",
        size: { cols: 1, rows: 1 },
        priority: 3,
      },
      {
        title: "New Alien Species",
        content:
          "Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.",
        image: "https://picsum.photos/id/3/600/400",
        size: { cols: 3, rows: 1 },
        priority: 2,
      },
      {
        title: "Technology Advances",
        content:
          "Maecenas sed diam eget risus varius blandit sit amet non magna. Donec ullamcorper nulla non metus auctor fringilla. Nullam quis risus eget urna mollis ornare vel eu leo.",
        image: "https://picsum.photos/id/4/600/400",
        size: { cols: 1, rows: 2 },
        priority: 2,
      },
      {
        title: "Colony Updates",
        content:
          "Etiam porta sem malesuada magna mollis euismod. Aenean lacinia bibendum nulla sed consectetur. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.",
        image: "https://picsum.photos/id/5/600/400",
        size: { cols: 2, rows: 1 },
        priority: 2,
      },
      {
        title: "Resource Management",
        content:
          "Integer posuere erat a ante venenatis dapibus posuere velit aliquet. Donec sed odio dui. Cras justo odio, dapibus ac facilisis in, egestas eget quam.",
        image: "https://picsum.photos/id/6/600/400",
        size: { cols: 1, rows: 1 },
        priority: 3,
      },
      {
        title: "Mission Briefing",
        content:
          "Vestibulum id ligula porta felis euismod semper. Sed posuere consectetur est at lobortis. Aenean eu leo quam. Pellentesque ornare sem lacinia quam venenatis vestibulum.",
        image: "https://picsum.photos/id/7/600/400",
        size: { cols: 2, rows: 2 },
        priority: 2, // Medium priority
      },
      {
        title: "Weather Anomalies",
        content:
          "Cras mattis consectetur purus sit amet fermentum. Nullam id dolor id nibh ultricies vehicula ut id elit. Nullam quis risus eget urna mollis ornare vel eu leo.",
        image: "https://picsum.photos/id/8/600/400",
        size: { cols: 1, rows: 1 },
        priority: 3,
      },
    ],
  };
}
