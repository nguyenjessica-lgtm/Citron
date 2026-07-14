// SPDX-FileCopyrightText: Copyright 2026 Citron Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <cstddef>

#include "common/common_types.h"

namespace Common::NvdecLifetimeTrace {

// Temporary, narrowly-scoped diagnostics for the recurring unmapped device reads seen in TotK.
constexpr DAddr TargetStart = 0xC7BDC000;
constexpr DAddr TargetEnd = 0xC7BDD000;

[[nodiscard]] constexpr bool Overlaps(DAddr address, std::size_t size) {
    return size != 0 && address < TargetEnd && address + size > TargetStart;
}

} // namespace Common::NvdecLifetimeTrace
