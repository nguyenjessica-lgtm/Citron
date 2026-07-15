// SPDX-FileCopyrightText: 2023 yuzu Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

package org.citron.citron_emu.ui

import android.content.SharedPreferences
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.preference.PreferenceManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import org.citron.citron_emu.layout.AutofitGridLayoutManager
import org.citron.citron_emu.R
import org.citron.citron_emu.adapters.GameAdapter
import org.citron.citron_emu.databinding.FragmentGamesBinding
import org.citron.citron_emu.model.GamesViewModel
import org.citron.citron_emu.model.HomeViewModel
import org.citron.citron_emu.utils.ViewUtils.setVisible
import org.citron.citron_emu.utils.ViewUtils.updateMargins
import org.citron.citron_emu.utils.collect

class GamesFragment : Fragment() {
    private var _binding: FragmentGamesBinding? = null
    private val binding get() = _binding!!

    private val gamesViewModel: GamesViewModel by activityViewModels()
    private val homeViewModel: HomeViewModel by activityViewModels()

    private lateinit var gameAdapter: GameAdapter
    private lateinit var preferences: SharedPreferences
    private var viewMode = VIEW_MODE_LIST

    companion object {
        private const val PREF_VIEW_MODE = "pref_games_view_mode"
        const val VIEW_MODE_LIST = 0
        const val VIEW_MODE_TILES_2 = 1
        const val VIEW_MODE_TILES_3 = 2
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentGamesBinding.inflate(inflater)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        homeViewModel.setNavigationVisibility(visible = true, animated = true)
        homeViewModel.setStatusBarShadeVisibility(true)

        preferences = PreferenceManager.getDefaultSharedPreferences(requireContext())
        viewMode = preferences.getInt(PREF_VIEW_MODE, VIEW_MODE_LIST)

        gameAdapter = GameAdapter(requireActivity() as AppCompatActivity, viewMode != VIEW_MODE_LIST)

        binding.gridGames.apply {
            layoutManager = layoutManagerForMode(viewMode)
            adapter = gameAdapter
        }

        binding.btnViewToggle.apply {
            setOnClickListener { toggleViewMode() }
        }
        updateToggleButton()

        binding.swipeRefresh.apply {
            // Add swipe down to refresh gesture
            setOnRefreshListener {
                // The pull indicator only acknowledges the gesture. The quieter progress
                // line represents the potentially long-running game scan.
                isRefreshing = false
                gamesViewModel.reloadGames(false)
            }
        }

        gamesViewModel.isReloading.collect(viewLifecycleOwner) {
            binding.scanProgress.setVisible(it)
            binding.noticeText.setVisible(
                visible = gamesViewModel.games.value.isEmpty() && !it,
                gone = false
            )
        }
        gamesViewModel.games.collect(viewLifecycleOwner) {
            gameAdapter.submitList(it)
        }
        gamesViewModel.shouldSwapData.collect(
            viewLifecycleOwner,
            resetState = { gamesViewModel.setShouldSwapData(false) }
        ) {
            if (it) {
                gameAdapter.submitList(gamesViewModel.games.value)
            }
        }
        gamesViewModel.shouldScrollToTop.collect(
            viewLifecycleOwner,
            resetState = { gamesViewModel.setShouldScrollToTop(false) }
        ) { if (it) scrollToTop() }

        setInsets()
    }
    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private fun layoutManagerForMode(mode: Int): RecyclerView.LayoutManager =
        when (mode) {
            VIEW_MODE_TILES_2 -> AutofitGridLayoutManager(
                requireContext(),
                resources.getDimensionPixelSize(R.dimen.card_width)
            )
            VIEW_MODE_TILES_3 -> AutofitGridLayoutManager(
                requireContext(),
                resources.getDimensionPixelSize(R.dimen.card_width_small)
            )
            else -> LinearLayoutManager(requireContext())
        }

    private fun updateToggleButton() {
        val (iconRes, descRes) = when (viewMode) {
            VIEW_MODE_LIST -> Pair(R.drawable.ic_view_grid, R.string.switch_to_grid_view)
            VIEW_MODE_TILES_2 -> Pair(R.drawable.ic_view_grid_3, R.string.switch_to_grid_view_3col)
            else -> Pair(R.drawable.ic_view_list, R.string.switch_to_list_view)
        }
        binding.btnViewToggle.setIconResource(iconRes)
        binding.btnViewToggle.contentDescription = getString(descRes)
    }

    private fun toggleViewMode() {
        viewMode = (viewMode + 1) % 3
        preferences.edit().putInt(PREF_VIEW_MODE, viewMode).apply()

        binding.gridGames.layoutManager = layoutManagerForMode(viewMode)
        gameAdapter.setTilesMode(viewMode != VIEW_MODE_LIST)
        // Force rebind when cycling between tile modes (both are VIEW_TYPE_TILES so
        // setTilesMode's guard won't call notifyDataSetChanged, but we need the grid
        // to re-measure with the new span count).
        if (viewMode != VIEW_MODE_LIST) {
            gameAdapter.notifyDataSetChanged()
        }
        updateToggleButton()
    }

    private fun scrollToTop() {
        if (_binding != null) {
            binding.gridGames.smoothScrollToPosition(0)
        }
    }

    private fun setInsets() =
        ViewCompat.setOnApplyWindowInsetsListener(
            binding.root
        ) { view: View, windowInsets: WindowInsetsCompat ->
            val barInsets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars())
            val cutoutInsets = windowInsets.getInsets(WindowInsetsCompat.Type.displayCutout())
            val extraListSpacing = resources.getDimensionPixelSize(R.dimen.spacing_large)
            val spacingNavigation = resources.getDimensionPixelSize(R.dimen.spacing_navigation)
            val spacingNavigationRail =
                resources.getDimensionPixelSize(R.dimen.spacing_navigation_rail)

            val leftInsets = barInsets.left + cutoutInsets.left
            val rightInsets = barInsets.right + cutoutInsets.right

            // spacing_navigation_rail is 80dp on w600dp screens, but this app has no
            // NavigationRailView — only a BottomNavigationView. Don't apply rail spacing.
            // spacing_navigation is 0dp on w600dp screens, but the BottomNavigationView is
            // still visible in landscape. Use spacing_navigation_rail as the bottom fallback
            // so the last row is never hidden behind the bottom nav.
            val bottomNav = maxOf(
                spacingNavigation,
                spacingNavigationRail  // 80dp on w600dp ≈ bottom nav height; 0dp elsewhere
            )
            binding.gridGames.updatePadding(
                top = barInsets.top + extraListSpacing,
                bottom = barInsets.bottom + bottomNav + extraListSpacing,
                left = 0,
                right = 0
            )

            binding.swipeRefresh.setProgressViewEndTarget(
                false,
                barInsets.top + resources.getDimensionPixelSize(R.dimen.spacing_refresh_end)
            )

            binding.swipeRefresh.updateMargins(left = leftInsets, right = rightInsets)

            binding.scanProgress.updateMargins(
                left = leftInsets,
                top = barInsets.top,
                right = rightInsets
            )

            binding.noticeText.updatePadding(bottom = spacingNavigation)

            // Push toggle button below status bar and clear of system bar / cutout on the end edge
            binding.btnViewToggle.updateMargins(
                top = barInsets.top + resources.getDimensionPixelSize(R.dimen.spacing_med),
                right = rightInsets + resources.getDimensionPixelSize(R.dimen.spacing_med)
            )

            windowInsets
        }
}
