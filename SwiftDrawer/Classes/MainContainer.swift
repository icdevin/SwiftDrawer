//
//  MainContainer.swift
//  DrawerDemo
//
//  Created by Millman on 2019/6/27.
//  Copyright © 2019 Millman. All rights reserved.
//

import SwiftUI
import Combine

struct MainContainer<Content: View>: View {
    @ObservedObject private var drawerControl: DrawerControl
    @ObservedObject private var leftRear: SliderStatus
    @ObservedObject private var rightRear: SliderStatus
    @State private var gestureCurrent: CGFloat = 0
    
    let main: AnyView
    private var maxMaskAlpha: CGFloat
    private var maskEnable: Bool
    var anyCancel: AnyCancellable?
    
    var body: some View {
        GeometryReader { proxy in
            self.generateBody(proxy: proxy)
        }.animation(.default)
    }
    
    init(
        content: Content,
        maxMaskAlpha: CGFloat = 0.25,
        maskEnable: Bool = true,
        drawerControl: DrawerControl
    ) {
        self.main = AnyView(content.environmentObject(drawerControl))
        self.maxMaskAlpha = maxMaskAlpha
        self.maskEnable = maskEnable
        self.drawerControl = drawerControl
        self.leftRear = drawerControl.status[.leftRear] ?? SliderStatus(type: .none)
        self.rightRear = drawerControl.status[.rightRear] ?? SliderStatus(type: .none)
    }
    
    func generateBody(proxy: GeometryProxy) -> some View {
        let haveRear = self.leftRear.type != .none || self.rightRear.type != .none
        let maxRadius = haveRear ? max(self.leftRear.shadowRadius, self.rightRear.shadowRadius) : 0
        let parentSize = proxy.size
        if haveRear {
            leftRear.parentSize = parentSize
            rightRear.parentSize = parentSize
        }
        
        return ZStack {
            self.main
            if maskEnable {
                Color.black
                    .opacity(Double(drawerControl.maxShowRate * self.maxMaskAlpha))
                    .animation(.easeIn(duration: 0.15))
                    .onTapGesture {
                        self.drawerControl.hideAllSlider()
                    }
                    .padding(EdgeInsets(
                        top: -proxy.safeAreaInsets.top,
                        leading: 0,
                        bottom: -proxy.safeAreaInsets.bottom,
                        trailing: 0
                    ))
            }
        }
        .offset(x: self.offset, y: 0)
        .shadow(radius: maxRadius)
        .gesture(DragGesture().onChanged({ value in
            let will = self.offset + (value.translation.width - self.gestureCurrent)
            if self.leftRear.type != .none {
                let range = 0...self.leftRear.sliderWidth
                var shouldMove: Bool {
                    switch self.rightRear.currentStatus {
                    case .show, .moving: return true
                    case .hide: return value.startLocation.x < 20
                    }
                }
                if range.contains(will) && shouldMove {
                    self.leftRear.currentStatus = .moving(offset: will)
                    self.gestureCurrent = value.translation.width
                }
            }

            if self.rightRear.type != .none {
                let range = (-self.rightRear.sliderWidth)...0
                var shouldMove: Bool {
                    switch self.rightRear.currentStatus {
                    case .show, .moving: return true
                    case .hide: return value.startLocation.x > proxy.size.width - 20
                    }
                }
                if range.contains(will) && shouldMove {
                    self.rightRear.currentStatus = .moving(offset: will)
                    self.gestureCurrent = value.translation.width
                }
            }
        }).onEnded({ value in
            let will = self.offset + (value.translation.width - self.gestureCurrent)
            if self.leftRear.type != .none {
                let range = 0...self.leftRear.sliderWidth
                if will - range.lowerBound <= range.upperBound - will {
                    self.leftRear.currentStatus = .hide
                } else if self.offset != 0 || value.startLocation.x < 20 {
                    self.leftRear.currentStatus = .show
                }
            }
            if self.rightRear.type != .none {
                let range = (-self.rightRear.sliderWidth)...0
                if will - range.lowerBound >= range.upperBound - will {
                    self.rightRear.currentStatus = .hide
                } else if self.offset != 0 || value.startLocation.x > proxy.size.width - 20 {
                    self.rightRear.currentStatus = .show
                }
            }
            self.gestureCurrent = 0
        }))
    }
    
    var offset: CGFloat {
        switch (self.leftRear.currentStatus, self.rightRear.currentStatus) {
        case (.hide, .hide):
            return 0
        case (.show, .hide):
            return self.leftRear.sliderOffset()
        case (.hide, .show):
            return self.rightRear.sliderOffset()
        default:
            if self.leftRear.currentStatus.isMoving {
                return self.leftRear.sliderOffset()
            } else if self.rightRear.currentStatus.isMoving {
                return self.rightRear.sliderOffset()
            }
        }
        return 0
    }
    
    var maxShowRate: CGFloat {
        return max(self.leftRear.showRate, self.rightRear.showRate)
    }
}

struct MainContainer_Previews: PreviewProvider {
    static var previews: some View {
        self.generate()
    }
    
    static func generate() -> some View {
        let view = DemoSlider(type: .leftRear)
        let c = DrawerControl()
        c.setSlider(view: view)
        return MainContainer(content: DemoMain(), drawerControl: c)
    }
}
