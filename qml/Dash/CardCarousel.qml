/*
 * Copyright (C) 2013-2015 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 0.1
import "../Components"

DashRenderer {
    id: cardCarousel

    expandedHeight: carousel.implicitHeight + units.gu(6)
    collapsedHeight: expandedHeight
    growsVertically: false
    innerWidth: carousel.innerWidth

    Carousel {
        id: carousel
        anchors.fill: parent
        tileAspectRatio: cardTool.components && cardTool.components["art"]["aspect-ratio"] || 1.0
        // FIXME we need to "reverse" the carousel to make the selected item the size
        // and push others back.
        minimumTileWidth: cardTool.cardWidth / selectedItemScaleFactor
        selectedItemScaleFactor: cardTool.carouselSelectedItemScaleFactor
        cacheBuffer: cardCarousel.cacheBuffer
        displayMarginBeginning: cardCarousel.displayMarginBeginning
        displayMarginEnd: cardCarousel.displayMarginEnd
        model: cardCarousel.model

        property real fontScale: 1 / selectedItemScaleFactor
        property real headerHeight: cardTool.headerHeight / selectedItemScaleFactor

        itemComponent: Loader {
            id: loader

            property bool explicitlyScaled
            property var model
            property int index
            enabled: false

            objectName: "carouselDelegate" + index

            function clicked() { cardCarousel.clicked(index, model.result, loader.item, model) }
            function pressAndHold() { cardCarousel.pressAndHold(index, model.result, model) }

            sourceComponent: cardTool.cardComponent
            asynchronous: true
            onLoaded: {
                item.fixedHeaderHeight = Qt.binding(function() { return carousel.headerHeight; });
                item.height = Qt.binding(function() { return cardTool.cardHeight; });
                item.cardData = Qt.binding(function() { return model; });
                item.template = Qt.binding(function() { return cardTool.template; });
                item.components = Qt.binding(function() { return cardTool.components; });
                item.fontScale = Qt.binding(function() { return carousel.fontScale; });
                item.showHeader = Qt.binding(function() { return loader.explicitlyScaled; });
                item.artShapeStyle = "flat";
                item.scopeStyle = cardCarousel.scopeStyle;
            }

            BorderImage {
                anchors {
                    fill: parent
                    margins: -units.gu(1)
                }
                z: -1
                source: "graphics/carousel_dropshadow.sci"
            }
        }
    }
}
