// SPDX-FileCopyrightText: Copyright 2026 Citron Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <cstddef>

#include "common/common_types.h"

namespace Common::NvdecLifetimeTrace {

// Temporary, narrowly-scoped diagnostics for device-memory lifetime issues observed on Windows
// and Android. End addresses are exclusive.
constexpr DAddr WindowsTargetStart = 0xC7BDC000;
constexpr DAddr WindowsTargetEnd = 0xC7BDD000;
constexpr DAddr AndroidTargetStart = 0x869F9000;
constexpr DAddr AndroidTargetEnd = 0x869FE000;

[[nodiscard]] constexpr bool OverlapsRange(DAddr address, std::size_t size, DAddr target_start,
                                           DAddr target_end) {
    return size != 0 && address < target_end && address + size > target_start;
}

[[nodiscard]] constexpr bool Overlaps(DAddr address, std::size_t size) {
    return OverlapsRange(address, size, WindowsTargetStart, WindowsTargetEnd) ||
           OverlapsRange(address, size, AndroidTargetStart, AndroidTargetEnd);
}

} // namespace Common::NvdecLifetimeTrace
