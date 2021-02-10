using Test
using Pluto
using Pluto: Configuration, update_run!, WorkspaceManager, ServerSession, ClientSession, Cell, Notebook

@testset "CellDepencencyVisualization" begin
    🍭 = ServerSession()
    🍭.options.evaluation.workspace_use_distributed = false

    fakeclient = ClientSession(:fake, nothing)
    🍭.connected_clients[fakeclient.id] = fakeclient

    notebook = Notebook([
                Cell("x = 1"), # prerequisite of test cell
                Cell("f(x) = x + y"), # depends on test cell
                Cell("f(4)"),

                Cell("""begin
                    g(a) = x
                    g(a,b) = y
                end"""), # depends on test cell
                Cell("y = x"), # test cell below
                Cell("g(6) + g(6,6)"),

                Cell("import Distributed"),
                Cell("Distributed.myid()"),
            ])
    fakeclient.connected_notebook = notebook
    update_run!(🍭, notebook, notebook.cells)

    ordered_cells = Pluto.get_ordered_cells(notebook)
    cell = notebook.cells_dict[notebook.cell_order[5]] # example cell
    @test Pluto.get_cell_number(cell, ordered_cells) == 2
    referenced_symbols = Pluto.get_referenced_symbols(cell, notebook)
    @test referenced_symbols == Set((:y,))

    references = Pluto.get_references(cell, notebook)
    @test Pluto.get_cell_number.(references[:y], Ref(notebook), Ref(ordered_cells)) == [3, 5] # these cells depend on selected cell
    dependencies = Pluto.get_dependencies(cell, notebook)
    @test Pluto.get_cell_number.(dependencies[:x], Ref(notebook), Ref(ordered_cells)) == [1] # selected cell depends on this cell

    # test if this information gets updated in the cell objects
    @test cell.cell_execution_order == 2
    @test cell.referenced_cells == references
    @test cell.dependent_cells == dependencies

    # test if this also works for function definitions
    cell2 = notebook.cells_dict[notebook.cell_order[2]]
    references2 = Pluto.get_references(cell2, notebook)
    @test Pluto.get_cell_number.(references2[:f], Ref(notebook), Ref(ordered_cells)) == [4] # these cells depend on selected cell
    dependencies2 = Pluto.get_dependencies(cell2, notebook)
    @test Pluto.get_cell_number.(dependencies2[:y], Ref(notebook), Ref(ordered_cells)) == [2] # selected cell depends on this cell
    @test Pluto.get_cell_number.(dependencies2[:+], Ref(notebook), Ref(ordered_cells)) == [] # + function is not defined / extended in the notebook


end
